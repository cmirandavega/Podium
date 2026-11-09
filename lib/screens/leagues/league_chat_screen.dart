import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/league_feature_service.dart';
import 'trade_proposal_screen.dart';

class LeagueChatScreen extends StatefulWidget {
  const LeagueChatScreen({super.key, required this.leagueId});
  final String leagueId;
  @override State<LeagueChatScreen> createState() => _LeagueChatScreenState();
}
class _LeagueChatScreenState extends State<LeagueChatScreen> {
  final api = LeagueFeatureService.instance;
  final input = TextEditingController();
  bool sending = false;
  String? pendingTrade;
  String? failedText;
  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty && pendingTrade == null) return;
    setState(() => sending=true);
    try {
      await api.sendMessage(widget.leagueId, text, tradeId:pendingTrade);
      input.clear(); setState(() { pendingTrade=null; failedText=null; });
    } catch (e) {
      final error = '$e';
      final blocked = error.contains('Message blocked') || error.contains('privileges have been suspended');
      setState(() => failedText = blocked ? null : text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(blocked ? error : 'Failed to send. Tap to retry. $error')));
    } finally { if (mounted) setState(() => sending=false); }
  }
  Future<void> linkTrade() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(context:context,builder:(context) => AlertDialog(
      title:const Text('Link existing trade'),
      content:TextField(controller:controller,decoration:const InputDecoration(labelText:'Trade ID')),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
        TextButton(onPressed:()=>Navigator.pop(context,controller.text.trim()),child:const Text('Attach'))],
    ));
    controller.dispose();
    if (id!=null && id.isNotEmpty) setState(()=>pendingTrade=id);
  }
  @override void dispose(){input.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream:api.league(widget.leagueId),builder:(context,leagueSnap){
        final league=leagueSnap.data?.data();
        if(league==null) return const Scaffold(body:Center(child:CircularProgressIndicator()));
        final isModerator=league['commissionerId']==api.uid;
        return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
          stream:api.db.collection('leagues').doc(widget.leagueId).collection('members').doc(api.uid).snapshots(),
          builder:(context,memberSnap){
            final member=memberSnap.data?.data();
            final muted=member?['isMuted']==true;
            if(member==null) return const Scaffold(body:Center(child:Text('Join this league to view chat.')));
            return Scaffold(appBar:AppBar(title:const Text('League Chat'),actions:[
              if(isModerator) IconButton(icon:const Icon(Icons.manage_accounts),tooltip:'Manage members',
                onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_MemberModerationScreen(leagueId:widget.leagueId)))),
            ]),body:Column(children:[
              Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                stream:api.chat(widget.leagueId),builder:(context,snap){
                  if(snap.hasError) return Center(child:Text('Unable to load messages: ${snap.error}'));
                  if(!snap.hasData) return const Center(child:CircularProgressIndicator());
                  return ListView.builder(reverse:true,itemCount:snap.data!.docs.length,itemBuilder:(context,i){
                    final message=snap.data!.docs[i], d=message.data();
                    final deleted=d['isDeleted']==true;
                    final trade='${d['tradeId'] ?? ''}';
                    return ListTile(
                      title:Text(deleted?'Message removed':'${d['body'] ?? ''}',
                        style:TextStyle(fontStyle:deleted?FontStyle.italic:FontStyle.normal)),
                      subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text('${d['senderId'] ?? 'System'}'),
                        if(!deleted && trade.isNotEmpty) TextButton.icon(
                          icon:const Icon(Icons.swap_horiz),label:Text('View trade $trade'),
                          onPressed:() async {
                            final tradeDoc=await api.db.collection('trades').doc(trade).get();
                            if(!context.mounted)return;
                            final detail=tradeDoc.data();
                            await showDialog<void>(context:context,builder:(_)=>AlertDialog(
                              title:const Text('Linked trade'),
                              content:Text('Trade: $trade\nStatus: ${detail?['status'] ?? 'Unavailable'}\n'
                                'Proposer: ${detail?['proposerTeamId'] ?? ''}\n'
                                'Recipient: ${detail?['receiverTeamId'] ?? ''}\n'
                                'Review and final processing follow the league trade rules.'),
                              actions:[
                                if(detail?['status']=='pending' && detail?['receiverTeamId']=='${widget.leagueId}_${api.uid}')
                                  TextButton(onPressed:() async {
                                    try{await api.respondTrade(trade,'reject');if(context.mounted)Navigator.pop(context);}
                                    catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
                                  },child:const Text('Reject')),
                                if(detail?['status']=='pending' && detail?['receiverTeamId']=='${widget.leagueId}_${api.uid}')
                                  TextButton(onPressed:() async {
                                    try{await api.respondTrade(trade,'accept');if(context.mounted)Navigator.pop(context);}
                                    catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
                                  },child:const Text('Accept for review')),
                                TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close')),
                              ]));
                          }),
                      ]),
                      trailing:isModerator && !deleted ? IconButton(
                        icon:const Icon(Icons.delete_outline),tooltip:'Remove message',onPressed:() async {
                          try { await api.deleteMessage(widget.leagueId,message.id); }
                          catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
                        }):null,
                    );
                  });
                },
              )),
              if(muted) const Padding(padding:EdgeInsets.all(14),
                child:Text('Your messaging privileges have been suspended by an administrator.')),
              if(failedText!=null && !muted) TextButton.icon(
                icon:const Icon(Icons.refresh),label:const Text('Failed to send. Tap to retry'),
                onPressed:sending?null:send),
              if(!muted) Padding(padding:const EdgeInsets.all(8),child:Row(children:[
                IconButton(icon:const Icon(Icons.swap_horiz),tooltip:'Propose trade',
                  onPressed:()=>Navigator.push(context,MaterialPageRoute(
                    builder:(_)=>TradeProposalScreen(leagueId:widget.leagueId)))),
                IconButton(icon:const Icon(Icons.add_link),tooltip:'Link trade',onPressed:linkTrade),
                Expanded(child:TextField(controller:input,maxLength:1000,maxLines:3,minLines:1,
                  decoration:InputDecoration(labelText:pendingTrade==null?'Message':'Trade attached: $pendingTrade',
                    counterText:''))),
                IconButton(icon:const Icon(Icons.send),onPressed:sending?null:send),
              ])),
            ]));
          },
        );
      },
    );
  }
}
class _MemberModerationScreen extends StatelessWidget {
  const _MemberModerationScreen({required this.leagueId});
  final String leagueId;
  @override Widget build(BuildContext context){
    final api=LeagueFeatureService.instance;
    return Scaffold(appBar:AppBar(title:const Text('Chat moderation')),
      body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:api.members(leagueId),builder:(context,snap){
          if(!snap.hasData)return const Center(child:CircularProgressIndicator());
          return ListView(children:snap.data!.docs.map((m)=>SwitchListTile(
            title:Text(m.id),subtitle:Text(m.data()['isMuted']==true?'Muted':'Can message'),
            value:m.data()['isMuted']==true,onChanged:m.id==api.uid?null:(value)async{
              try{await api.muteMember(leagueId,m.id,value);}
              catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
            },
          )).toList());
        },
      ),
    );
  }
}
