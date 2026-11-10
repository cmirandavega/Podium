'use strict';
// Isolated Podium UC2/3/7 exports. Merge these exports into existing functions/index.js if one exists.
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const {validId,validSports,badLanguage} = require('./validation');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const FV = admin.firestore.FieldValue;
const T = admin.firestore.Timestamp;
const REGION = 'us-central1';
const fail = (code, msg) => { throw new HttpsError(code, msg); };
const requireUser = async (request) => {
  const uid = request.auth?.uid;
  if (!uid) fail('unauthenticated', 'Please log in.');
  const user = (await db.doc(`users/${uid}`).get()).data();
  if (!user || !['active','warned'].includes(user.status)) fail('permission-denied', 'Account not active.');
  return { uid, user };
};
const leagueRef = id => db.collection('leagues').doc(id);
const requireLeague = async (tx, leagueId) => {
  if (!validId(leagueId)) fail('invalid-argument', 'Invalid league ID.');
  const ref = leagueRef(leagueId), snap = await tx.get(ref);
  if (!snap.exists) fail('not-found', 'League does not exist.');
  return {ref, league:snap.data()};
};
const eligibleSports = async (tx, sports) => {
  if (!validSports(sports)) {
    fail('invalid-argument', 'Select at least one available sport without duplicates.');
  }
  const docs = await Promise.all(sports.map(s => tx.get(db.doc(`sports/${s}`))));
  if (docs.some(s => !s.exists || s.data().isActive !== true))
    fail('failed-precondition', 'A selected sport is unavailable.');
};
const member = async (tx, leagueId, uid) => {
  const ref = leagueRef(leagueId);
  const snap = await tx.get(ref.collection('members').doc(uid));
  if (snap.exists) return snap.data();
  // Leagues created by the app keep members in the memberIds array.
  const league = await tx.get(ref);
  const ids = league.exists ? (league.data().memberIds || []) : [];
  if (!ids.includes(uid)) fail('permission-denied', 'You must join this league.');
  return { userId: uid, isMuted: false };
};
exports.podiumCreateLeague = onCall({region:REGION}, async request => {
  const {uid} = await requireUser(request);
  const {name, sports, season, maxTeams, rosterSize} = request.data || {};
  if (typeof name !== 'string' || !name.trim() || name.length > 80 ||
      typeof season !== 'string' || !season.trim() || season.length > 30 ||
      !Number.isInteger(maxTeams) || maxTeams < 2 || maxTeams > 20 ||
      !Number.isInteger(rosterSize) || rosterSize < 1 || rosterSize > 30)
    fail('invalid-argument', 'Invalid league name, season or roster limits.');
  const ref = db.collection('leagues').doc();
  await db.runTransaction(async tx => {
    await eligibleSports(tx, sports);
    tx.create(ref, {leagueId:ref.id, name:name.trim(), commissionerId:uid,
      format:sports.length === 1 ? 'single-sport':'multi-sport',
      sports, season:season.trim(), maxTeams, rosterSize,
      tradeReviewHours:24, status:'active', createdAt:FV.serverTimestamp()});
    for (const sport of sports) tx.create(db.doc(`leagueSports/${ref.id}_${sport}`), {leagueId:ref.id, sportName:sport});
    tx.create(ref.collection('members').doc(uid), {userId:uid,isMuted:false,joinedAt:FV.serverTimestamp()});
    tx.create(db.doc(`teams/${ref.id}_${uid}`), {leagueId:ref.id, ownerId:uid, teamName:'My Team',createdAt:FV.serverTimestamp()});
  });
  return {leagueId:ref.id};
});
exports.podiumUpdateSports = onCall({region:REGION}, async request => {
  const {uid} = await requireUser(request);
  const {leagueId, sports} = request.data || {};
  await db.runTransaction(async tx => {
    const {ref,league} = await requireLeague(tx,leagueId);
    if (league.commissionerId !== uid) fail('permission-denied', 'Only commissioner can edit sports.');
    await eligibleSports(tx, sports);
    const slots = await tx.get(db.collection('rosterSlots').where('leagueId','==',leagueId));
    const removed = (league.sports || []).filter(s => !sports.includes(s));
    if (removed.length && !slots.empty) fail('failed-precondition', 'Cannot remove a sport after rosters have been drafted.');
    tx.update(ref,{sports, format:sports.length===1?'single-sport':'multi-sport'});
    for (const s of league.sports||[]) if (!sports.includes(s)) tx.delete(db.doc(`leagueSports/${leagueId}_${s}`));
    for (const s of sports) if (!(league.sports||[]).includes(s)) tx.create(db.doc(`leagueSports/${leagueId}_${s}`),{leagueId,sportName:s});
  });
  return {ok:true};
});
exports.podiumJoinLeague = onCall({region:REGION}, async request => {
  const {uid}=await requireUser(request);
  const {leagueId}=request.data||{};
  await db.runTransaction(async tx => {
    const {ref,league}=await requireLeague(tx,leagueId);
    if(league.status!=='active')fail('failed-precondition','League is not active.');
    const membership=ref.collection('members').doc(uid);
    if((await tx.get(membership)).exists)return;
    const members=await tx.get(ref.collection('members'));
    if(members.size>=league.maxTeams)fail('resource-exhausted','League is full.');
    tx.create(membership,{userId:uid,isMuted:false,joinedAt:FV.serverTimestamp()});
    tx.create(db.doc(`teams/${leagueId}_${uid}`),{leagueId,ownerId:uid,teamName:'My Team',createdAt:FV.serverTimestamp()});
  });
  return {ok:true};
});
exports.podiumRosterAction = onCall({region:REGION}, async request => {
  const {uid}=await requireUser(request);
  const {leagueId,operation,playerId,replacementId,periodId,isStarter}=request.data||{};
  if(!['add','remove','replace','starter'].includes(operation))fail('invalid-argument','Invalid roster operation.');
  if(!validId(periodId)||!validId(playerId)||(operation==='replace'&&!validId(replacementId)))
    fail('invalid-argument','Choose a scoring period and valid athlete.');
  const teamId=`${leagueId}_${uid}`;
  await db.runTransaction(async tx => {
    const {league}=await requireLeague(tx,leagueId);
    await member(tx,leagueId,uid);
    const period = await tx.get(db.doc(`scoringPeriods/${periodId}`));
    if(!period.exists || !(period.data().lockTime instanceof T))
      fail('failed-precondition','Scoring period or lock time unavailable.');
    if(period.data().lockTime.toMillis()<=Date.now())fail('failed-precondition','Lineup is locked.');
    if(league.status!=='active')fail('failed-precondition','League is not active.');
    const team = await tx.get(db.doc(`teams/${teamId}`));
    if(!team.exists || team.data().ownerId!==uid)fail('permission-denied','Team not found.');
    const slots = await tx.get(db.collection('rosterSlots').where('teamId','==',teamId));
    const roster = slots.docs.map(s=>({ref:s.ref,...s.data()}));
    const current = roster.find(s=>s.playerId===playerId);
    const oldRef=db.doc(`rosterSlots/${leagueId}_${playerId}`);
    if(operation!=='add'&&!current)fail('failed-precondition','Athlete not on your team.');
    if(operation==='add'&&roster.length>=league.rosterSize)fail('failed-precondition','Roster limit reached.');
    const newId=operation==='replace'?replacementId:playerId;
    let athlete;
    if(operation==='add'||operation==='replace') {
      if(operation==='replace'&&playerId===replacementId)fail('invalid-argument','Choose a different athlete.');
      const candidate=await tx.get(db.doc(`players/${newId}`));
      if(!candidate.exists)fail('not-found','Athlete not found in sports data.');
      athlete=candidate.data();
      if(!(league.sports||[]).includes(athlete.sport)||
          ['inactive','unavailable','ineligible'].includes((athlete.injuryStatus||'').toLowerCase()))
        fail('failed-precondition','Athlete is unavailable or ineligible for this league.');
      if((await tx.get(db.doc(`rosterSlots/${leagueId}_${newId}`))).exists)
        fail('already-exists','Athlete is already drafted in this league.');
      const limits=league.positionLimits||{};
      const count=roster.filter(s=>s.slotPosition===athlete.position && s.playerId!==playerId).length;
      if(Number.isInteger(limits[athlete.position])&&count>=limits[athlete.position])
        fail('failed-precondition',`Position limit reached for ${athlete.position}.`);
    }
    const lineRef=db.doc(`lineups/${teamId}_${periodId}`);
    const lineSnap=await tx.get(lineRef);
    let starters=lineSnap.exists?(lineSnap.data().starters||[]).slice():[];
    if(operation==='starter'){
      if(typeof isStarter!=='boolean')fail('invalid-argument','Select starter or bench.');
      starters=starters.filter(id=>id!==playerId);
      if(isStarter)starters.push(playerId);
      const cap=league.starterLimit||league.rosterSize;
      if(starters.length>cap)fail('failed-precondition','Starting lineup limit reached.');
      const starterLimits=league.starterPositionLimits||{};
      const starterRoster=roster.filter(s=>starters.includes(s.playerId));
      const positionCount=starterRoster.filter(s=>s.slotPosition===current.slotPosition).length;
      if(Number.isInteger(starterLimits[current.slotPosition]) &&
          positionCount>starterLimits[current.slotPosition])
        fail('failed-precondition',`Starting lineup position limit reached for ${current.slotPosition}.`);
      tx.update(oldRef,{isStarter});
    } else if(operation==='remove'||operation==='replace') {
      starters=starters.filter(id=>id!==playerId);
      tx.delete(oldRef);
    }
    if(operation==='add'||operation==='replace') {
      tx.create(db.doc(`rosterSlots/${leagueId}_${newId}`),{
        leagueId,playerId:newId,teamId,slotPosition:athlete.position||'UTIL',
        isStarter:false,acquiredAt:FV.serverTimestamp()});
    }
    tx.set(lineRef,{leagueId,teamId,periodId,starters,updatedAt:FV.serverTimestamp()});
  });
  return {ok:true};
});
exports.podiumSendMessage = onCall({region:REGION},async request=>{
  const {uid}=await requireUser(request);
  const {leagueId,body,tradeId}=request.data||{};
  if(typeof body!=='string'||body.length>1000||(!body.trim()&&!tradeId))
    fail('invalid-argument','Enter a message of at most 1000 characters.');
  if(badLanguage(body))fail('failed-precondition','Message blocked due to inappropriate language.');
  const ref=leagueRef(leagueId);
  const message=ref.collection('messages').doc();
  await db.runTransaction(async tx=>{
    await requireLeague(tx,leagueId);
    const m=await member(tx,leagueId,uid);
    if(m.isMuted===true)fail('permission-denied','Your messaging privileges have been suspended by an administrator.');
    if(tradeId!=null){
      if(!validId(tradeId))fail('invalid-argument','Invalid trade ID.');
      const trade=await tx.get(db.doc(`trades/${tradeId}`));
      if(!trade.exists||trade.data().leagueId!==leagueId)
        fail('failed-precondition','Trade not found in this league.');
    }
    tx.create(message,{senderId:uid,body:body.trim(),isDeleted:false,
      createdAt:FV.serverTimestamp(),...(tradeId?{tradeId}:{}),type:tradeId?'trade':'text'});
  });
  return {messageId:message.id};
});
exports.podiumModerateChat=onCall({region:REGION},async request=>{
  const {uid,user}=await requireUser(request);
  const {leagueId,action,messageId,userId,muted}=request.data||{};
  await db.runTransaction(async tx=>{
    const {league}=await requireLeague(tx,leagueId);
    if(league.commissionerId!==uid&&user.role!=='admin')
      fail('permission-denied','Moderator access required.');
    if(action==='delete'){
      if(!validId(messageId))fail('invalid-argument','Invalid message ID.');
      const ref=leagueRef(leagueId).collection('messages').doc(messageId);
      if(!(await tx.get(ref)).exists)fail('not-found','Message missing.');
      tx.update(ref,{isDeleted:true,body:'',tradeId:FV.delete(),deletedBy:uid});
    }else if(action==='mute'){
      if(!validId(userId)||typeof muted!=='boolean'||userId===league.commissionerId)
        fail('invalid-argument','Invalid member or mute setting.');
      const ref=leagueRef(leagueId).collection('members').doc(userId);
      const snap=await tx.get(ref);
      if(!snap.exists && !(league.memberIds||[]).includes(userId))fail('not-found','Member missing.');
      tx.set(ref,{userId,isMuted:muted},{merge:true})
    }else fail('invalid-argument','Unknown moderation action.');
  });
  return {ok:true};
});
// Writes in-app notifications for other members and sends push to devices with registered tokens.
exports.podiumChatNotify = onDocumentCreated({document:'leagues/{leagueId}/messages/{messageId}',region:REGION},async event=>{
  const msg=event.data?.data();if(!msg)return;
  const {leagueId,messageId}=event.params;
  const sender=msg.senderId||msg.userId||msg.authorId;
  const leagueSnap=await leagueRef(leagueId).get();
  const memberDocs=await leagueRef(leagueId).collection('members').get();
  const ids=new Set([...(leagueSnap.data()?.memberIds||[]),...memberDocs.docs.map(d=>d.id)]);
  const leagueName=leagueSnap.data()?.name||'your league';
  for(const id of ids){
    if(id===sender)continue;
    await db.collection('notifications').add({userId:id,type:'league_chat',
      message:`New message in ${leagueName}`,relatedId:leagueId,isRead:false,
      createdAt:FV.serverTimestamp()});
    const tokens=await db.collection('users').doc(id).collection('fcmTokens').get();
    const values=tokens.docs.map(t=>t.id);
    if(values.length){
      try { await admin.messaging().sendEachForMulticast({tokens:values.slice(0,500),
        notification:{title:'Podium league chat',body:'New league message'},
        data:{leagueId,messageId}}); }catch(err){console.error('Push failed',err);}
    }
  }
});
// League chat trade shortcut: creates a proposed trade (not a roster transfer).
exports.podiumProposeTrade = onCall({region:REGION},async request=>{
  const {uid}=await requireUser(request);
  const {leagueId,receiverId,offeredIds,requestedIds}=request.data||{};
  if(!validId(receiverId)||receiverId===uid||!Array.isArray(offeredIds)||
    !Array.isArray(requestedIds)||!offeredIds.length||!requestedIds.length||
    offeredIds.length>15||requestedIds.length>15||
    [...offeredIds,...requestedIds].some(id=>!validId(id))||
    new Set([...offeredIds,...requestedIds]).size!==offeredIds.length+requestedIds.length)
    fail('invalid-argument','Select valid players from both teams.');
  const proposerTeamId=`${leagueId}_${uid}`, receiverTeamId=`${leagueId}_${receiverId}`;
  const trade=db.collection('trades').doc(), msg=leagueRef(leagueId).collection('messages').doc();
  await db.runTransaction(async tx=>{
    const {league}=await requireLeague(tx,leagueId);
    const proposer = await member(tx,leagueId,uid);
    if(proposer.isMuted===true)fail('permission-denied','Your messaging privileges have been suspended by an administrator.');
    await member(tx,leagueId,receiverId);
    const slots=await Promise.all([...offeredIds,...requestedIds]
      .map(id=>tx.get(db.doc(`rosterSlots/${leagueId}_${id}`))));
    slots.forEach((slot,i)=>{
      const team=i<offeredIds.length?proposerTeamId:receiverTeamId;
      if(!slot.exists||slot.data().teamId!==team)
        fail('failed-precondition','Proposed trade contains athletes not on selected teams.');
    });
    tx.create(trade,{tradeId:trade.id,leagueId,proposerTeamId,receiverTeamId,
      parentTradeId:null,status:'pending',createdAt:FV.serverTimestamp(),
      reviewEndsAt:null,tradeReviewHours:league.tradeReviewHours||24});
    for(const id of offeredIds)tx.create(trade.collection('items').doc(id),{playerId:id,fromTeamId:proposerTeamId});
    for(const id of requestedIds)tx.create(trade.collection('items').doc(id),{playerId:id,fromTeamId:receiverTeamId});
    tx.create(msg,{senderId:uid,body:'Trade proposal',type:'trade',tradeId:trade.id,
      isDeleted:false,createdAt:FV.serverTimestamp()});
  });
  return {tradeId:trade.id};
});
exports.podiumRespondTrade = onCall({region:REGION},async request=>{
  const {uid}=await requireUser(request);
  const {tradeId,decision}=request.data||{};
  if(!validId(tradeId)||!['accept','reject'].includes(decision))fail('invalid-argument','Invalid trade response.');
  await db.runTransaction(async tx=>{
    const ref=db.doc(`trades/${tradeId}`),snap=await tx.get(ref);
    if(!snap.exists)fail('not-found','Trade does not exist.');
    const d=snap.data();
    await member(tx,d.leagueId,uid);
    if(d.receiverTeamId!==`${d.leagueId}_${uid}`)fail('permission-denied','Only the receiving team may respond.');
    if(d.status!=='pending')fail('failed-precondition','Trade no longer pending.');
    tx.update(ref,{status:decision==='reject'?'rejected':'in_review',
      reviewEndsAt:decision==='accept'?T.fromMillis(Date.now()+(d.tradeReviewHours||24)*3600000):null});
  });
  return {ok:true};
});
