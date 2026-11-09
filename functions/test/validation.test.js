'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {validId,validSports,badLanguage}=require('../validation');
test('sport selection requires 1-4 distinct IDs',()=>{
  assert.equal(validSports([]),false);
  assert.equal(validSports(['NBA']),true);
  assert.equal(validSports(['NBA','NFL','MLB','soccer']),true);
  assert.equal(validSports(['NBA','NBA']),false);
  assert.equal(validSports(['NBA','NFL','MLB','soccer','NHL']),false);
});
test('document IDs disallow slashes and empty IDs',()=>{
  assert.equal(validId('NBA_123'),true);
  assert.equal(validId('../admin'),false);
  assert.equal(validId(''),false);
});
test('message language filter',()=>{
  assert.equal(badLanguage('Good game team!'),false);
  assert.equal(badLanguage('what the shit'),true);
  assert.equal(badLanguage('Nice shot'),false);
});
