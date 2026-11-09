import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/league_feature_service.dart';

/// Shortcut for creating a trade proposal directly from league chat.
/// Trade execution and commissioner approval are handled by Use Case 8.
class TradeProposalScreen extends StatefulWidget {
  const TradeProposalScreen({super.key,required this.leagueId});
  final String leagueId;
  @override State<TradeProposalScreen> createState()=>_TradeProposalScreenState();
}
class _TradeProposalScreenState extends State<TradeProposalScreen> {
  final api=LeagueFeatureService.instance;
  String? receiverId;
  final offered=<String>{},requested=<String>{};
  bool saving=false;
  Future<void> submit() async {
    if(receiverId==null||offered.isEmpty||requested.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Choose a team and players from each roster.')));
      return;
    }
    setState(()=>saving=true);
    try {
      await api.proposeTrade(widget.leagueId,receiverId!,offered.toList(),requested.toList());
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar:AppBar(title:const Text('Propose trade')),
      body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:api.members(widget.leagueId),builder:(context,ms){
          if(!ms.hasData)return const Center(child:CircularProgressIndicator());
          final others=ms.data!.docs.where((m)=>m.id!=api.uid).toList();
          return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
            stream:api.db.collection('rosterSlots').where('leagueId',isEqualTo:widget.leagueId).snapshots(),
            builder:(context,rosterSnap){
              if(!rosterSnap.hasData)return const Center(child:CircularProgressIndicator());
              final entries=rosterSnap.data!.docs;
              return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                stream:api.players(),builder:(context,playerSnap){
                  if(!playerSnap.hasData)return const Center(child:CircularProgressIndicator());
                  final names={for(final p in playerSnap.data!.docs) p.id:'${p.data()['fullName'] ?? p.id}'};
                  final mine=entries.where((s)=>s.data()['teamId']=='${widget.leagueId}_${api.uid}').toList();
                  final theirs=entries.where((s)=>s.data()['teamId']=='${widget.leagueId}_$receiverId').toList();
                  return ListView(padding:const EdgeInsets.all(16),children:[
                    DropdownButtonFormField<String>(initialValue:others.any((o)=>o.id==receiverId)?receiverId:null,
                      decoration:const InputDecoration(labelText:'Trade with'),
                      items:others.map((m)=>DropdownMenuItem(value:m.id,child:Text(m.id))).toList(),
                      onChanged:(v)=>setState((){receiverId=v;requested.clear();})),
                    const SizedBox(height:18),
                    const Text('Players you offer',style:TextStyle(fontWeight:FontWeight.bold)),
                    ...mine.map((s){
                      final id='${s.data()['playerId']}';
                      return CheckboxListTile(title:Text(names[id] ?? id),value:offered.contains(id),
                        onChanged:(checked)=>setState(()=>checked==true?offered.add(id):offered.remove(id)));
                    }),
                    const SizedBox(height:18),
                    const Text('Players you request',style:TextStyle(fontWeight:FontWeight.bold)),
                    ...theirs.map((s){
                      final id='${s.data()['playerId']}';
                      return CheckboxListTile(title:Text(names[id] ?? id),value:requested.contains(id),
                        onChanged:(checked)=>setState(()=>checked==true?requested.add(id):requested.remove(id)));
                    }),
                    if(receiverId!=null && theirs.isEmpty)const Text('That team has not drafted athletes yet.'),
                    const SizedBox(height:18),
                    FilledButton(onPressed:saving?null:submit,
                      child:Text(saving?'Sending...':'Send trade proposal to chat')),
                  ]);
                },
              );
            },
          );
        },
      ),
    );
  }
}
