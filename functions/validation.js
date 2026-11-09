'use strict';
const blockedWords = ['fuck','shit','bitch','cunt','nigger','faggot'];
function validId(id){
  return typeof id === 'string' && /^[a-zA-Z0-9_-]{1,150}$/.test(id);
}
function validSports(sports) {
  return Array.isArray(sports) && sports.length>=1 && sports.length<=4 &&
    new Set(sports).size===sports.length && sports.every(validId);
}
function badLanguage(body){
  if(typeof body!=='string')return true;
  const normalized=body.toLowerCase().replace(/[^a-z]/g,' ');
  return blockedWords.some(word=>new RegExp(`(^|\\s)${word}(\\s|$)`).test(normalized));
}
module.exports={validId,validSports,badLanguage};
