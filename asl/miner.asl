// miner agent

{ include("moving.asl") }               // plans for movements in the scenario
{ include("search_unvisited.asl") }     // plans for finding gold
{ include("search_quadrant.asl") }      // idem
{ include("fetch_gold.asl") }           // plans for fetch gold goal
{ include("goto_depot.asl") }           // plans for go to depot goal
{ include("allocation_protocol.asl") }  // plans for the gold allocation protocol

/* functions */

{ register_function("carrying.gold",0,"carrying_gold") }
{ register_function("jia.path_length",4,"jia.path_length") }

//----------------------------------------BELIEFS--------------------------------//
free.
my_capacity(3).
search_gold_strategy(near_unvisited).       // initial strategy
last_pickup_location(none, none).           // remember last location pickup
no_gold_found_cycles(0).                    // gold not found counter
search_attempts_without_gold(0).  // Track unsuccessful searches
quadrant_search_enabled(false).   // Track if we're using quadrant search


//----------------------------------------INIT----------------------------------------//
+pos(_,_,0)
  <- ?gsize(S,_,_);
     .print("========== MINER AGENT INITIALIZED ==========");
     .print("Starting simulation ", S);
     !inform_gsize_to_leader(S);
     !choose_goal.

+!inform_gsize_to_leader(S) : .my_name(miner1)
   <- ?depot(S,DX,DY);
      .send(leader,tell,depot(S,DX,DY));
      ?gsize(S,W,H);
      .send(leader,tell,gsize(S,W,H)).
+!inform_gsize_to_leader(_).

//----------------------------------------PERIODIC CHECKS----------------------------------------//
+step(S) 
  :  S mod 10 == 0 
  <- !adjust_search_strategy.

/* Search Strategy Adjustment */
+!adjust_search_strategy
  :  search_attempts_without_gold(N) & N > 15 &
     not quadrant_search_enabled(true)
  <- -+quadrant_search_enabled(true);
     -+search_gold_strategy(quadrant);
     .print("=== Switching to quadrant search strategy after ", N, " unsuccessful attempts").

+!adjust_search_strategy
  :  quadrant_search_enabled(true) &
     gold(_, _)
  <- -+quadrant_search_enabled(false);
     -+search_gold_strategy(near_unvisited);
     -+search_attempts_without_gold(0);
     .print("=== Found gold! Switching back to near_unvisited strategy").

// Default case when no adjustment needed
+!adjust_search_strategy.

+quadrant(X1,Y1,X2,Y2)
  <- .findall(miner(MX,MY), jia.ag_pos(M,MX,MY), Miners);
     .print("=== Assigned to quadrant [", X1, ",", Y1, ",", X2, ",", Y2, "]");
     +my_quadrant(X1,Y1,X2,Y2).

+carrying_gold(N) : N > 0
  <- .send(leader, tell, miner_status(N)).
//-------------------------------HANDLE RETURN AT ENDGAME-----------------------//
@cgod2[atomic]
+!choose_goal
 :  steps(_,TotalSteps) &
    pos(_,_,CurrentStep) &
    TotalSteps - CurrentStep < 50 &    // less than 50 cycles left
    carrying_gold(NG) & NG > 0          // carrying any amount of gold
 <- .print("=== ENDGAME: Less than 50 cycles left, going to depot with ", NG, " gold");
    !change_to_goto_depot.

//----------------------------------GOALS---------------------------------//
// GOT SPACE AND WORTH
+!choose_goal
 :  container_has_space &               // I have space for more gold
    .findall(gold(X,Y),gold(X,Y),LG) &  // LG is all known golds
    evaluate_golds(LG,LD) &             // evaluate golds in LD
    .print("All golds=",LG,", evaluation=",LD) &
    .length(LD) > 0 &                   // is there a gold to fetch?
    .min(LD,d(D,NewG,_)) &              // get the near
    worthwhile(NewG)
 <- .print("Gold options are ",LD,". Next gold is ",NewG);
    !change_to_fetch(NewG).

// GOT 1 SPACE AND NOT_WORTH
+!choose_goal // there is no worth gold
 :  carrying_gold(NG) & NG >= 2
 <- !change_to_goto_depot.

// GOT 2+ SPACE -> SEARCH
 +!choose_goal // keep searching if carrying less than 2 gold
 :  carrying_gold(NG) & NG > 0 & NG < 2
 <- !change_to_search.

// GOT 3 SPACE -> SEARCH
+!choose_goal // not carrying gold, be free and search gold
 <- !change_to_search.

//------------------------------DEPOT HANDLING------------------------------------------//
+!change_to_goto_depot              // Im already on the way to DEPOT     
  :  .desire(goto_depot)
  <- .print("do not need to change to goto_depot").

+!change_to_goto_depot              // If I have desire to fetch gold by I got requested to go to DEPOT  
  :  .desire(fetch_gold(G))
  <- .drop_desire(fetch_gold(G));
     !change_to_goto_depot.

+!change_to_goto_depot              // Requested to DEPOT but doing nothing
  <- -free;
     !!goto_depot.


//-------------------------------FETCH GOLD HANDLING-----------------------------------//
+!change_to_fetch(G)               // Doing nothing
  :  .desire(fetch_gold(G)).

+!change_to_fetch(G)               // Going to DEPOT but GOLD is near
  :  .desire(goto_depot)
  <- .drop_desire(goto_depot);
     !change_to_fetch(G).

+!change_to_fetch(G)               // Went for GOLD but there is one closer
  :  .desire(fetch_gold(OtherG))
  <- .drop_desire(fetch_gold(OtherG));
     !change_to_fetch(G).

+!change_to_fetch(G)                // Handle when not free but doing nothing
  <- -free;
     !!fetch_gold(G).


//-------------------------------SEARCH GOLD HANDLING-----------------------------------//
+!change_to_search
  :  search_gold_strategy(S)
  <- .print("New goal is find gold: ",S);
     -free;
     +free;
     .drop_all_desires;
     .print("=== Broadcasting request for gold information");
     .broadcast(tell, request_gold_info);
     !!search_gold(S).


//------------------------------EVALUATE GOLD WORTH--------------------------------------//
evaluate_golds([],[]) :- true.
evaluate_golds([gold(GX, GY)|R],[d(Utility,gold(GX,GY),Annot)|RD])
  :- evaluate_gold(gold(GX,GY),Utility,Annot) &
     evaluate_golds(R,RD).
evaluate_golds([_|R],RD)
  :- evaluate_golds(R,RD).

evaluate_gold(gold(X,Y),Utility,Annot)
  :- pos(AgX,AgY,_) & 
     jia.path_length(AgX,AgY,X,Y,PathLength) &
     calculate_gold_utility(PathLength, X, Y, Utility) &
     check_commit(gold(X,Y),Utility,Annot).

calculate_gold_utility(PathLength, GoldX, GoldY, Utility)
  :- 
     // Optimize by doing distance calculations first
     pos(AgX,AgY,_) &
     depot(_,DepotX,DepotY) &
     jia.path_length(GoldX,GoldY,DepotX,DepotY,DepotDistance) &
     
     // Consider more factors in utility
     carrying_gold(NG) &
     BaseUtility = PathLength * (NG + 1) &  // Factor in current load
     DepotFactor = DepotDistance / (20 - NG * 2) &  // More sensitive to depot distance when carrying more
     
     // Final calculation with adjusted weights
     Utility = BaseUtility + DepotFactor.

// Enhanced commitment checking with more context
check_commit(G,Utility,not_committed) :- 
     not committed_to(G,_,_).

check_commit(gold(X,Y),MyD,committed_by(Ag,at(OtX,OtY),far(OtD)))
  :- committed_to(gold(X,Y),_,Ag) &          
     jia.ag_pos(Ag,OtX,OtY) &                
     jia.path_length(OtX,OtY,X,Y,OtD) &      
     MyD < OtD.  // Prioritize if agent is closer


worthwhile(gold(_,_)) :-
     carrying_gold(0). // Always go for gold if carrying none
worthwhile(gold(GX,GY)) :-
     carrying_gold(NG) & NG > 0 &
     pos(AgX,AgY,Step) &
     depot(_,DX,DY) &
     steps(_,TotalSteps) &
     AvailableSteps = TotalSteps - Step &

     // Enhanced fatigue and path calculation
     jia.add_fatigue(jia.path_length(AgX,AgY,GX,GY),NG,  PathToGold) & // ag to gold
     jia.add_fatigue(jia.path_length(GX,GY,DX,DY),NG+1,PathToDepot) & // go to depot

     // More nuanced worthiness calculation
     TotalPathCost = PathToGold + PathToDepot &
     MarginFactor = 1.8 & // Allow slightly more risky paths
     AvailableSteps > (TotalPathCost * MarginFactor) &
     
     // Additional strategic considerations
     (NG < my_capacity &  // Not at full capacity
      jia.path_length(AgX,AgY,GX,GY) <15). // Gold is relatively close




//----------------------------------PERCEPTIONS----------------------------------------//
// I perceived unknown gold, decide next gold
@pcell0[atomic]          // atomic: so as not to handle another
                         // event until handle gold is carrying on
+cell(X,Y,gold)
  :  not gold(X,Y)  // it's a new gold discovery
  <- .print("=== New gold discovered at [", X, ",", Y, "]");
     -+search_attempts_without_gold(0);  // Reset counter when gold found
     +gold(X,Y);
     +announced(gold(X,Y));
     .broadcast(tell,gold(X,Y));
     if (container_has_space) {
         !choose_goal;
     }.

+cell(X,Y,empty)
  :  gold(X,Y)
  <- .print("=== Broadcasting gold pickup at [", X, ",", Y, "]");
     !remove(gold(X,Y));
     .broadcast(tell,picked(gold(X,Y))).
// Share all known golds when a new miner joins or requests info
+request_gold_info[source(Miner)]
  <- .findall(gold(X,Y), gold(X,Y), GoldList);
     .print("=== Sharing gold information with ", Miner, ": ", GoldList);
     .send(Miner, tell, known_golds(GoldList)).

// Handle received gold information from other miners
+known_golds(GoldList)[source(Miner)]
  <- .print("=== Received gold information from ", Miner);
     for (.member(Gold, GoldList)) {
         if (not gold(Gold)) {
             +gold(Gold);
             .print("=== Added new gold location from ", Miner, ": ", Gold);
         }
     }.

// If I see an empty cell where it was supposed to be gold, announce it to others
+cell(X,Y,empty)
  :  gold(X,Y) &
     not .desire(fetch_gold(gold(X,Y))) // in this case, I empty the cell!
  <- !remove(gold(X,Y));
     .print("The gold at ",X,",",Y," was picked by someone else! Announcing to others.");
     .broadcast(tell,picked(gold(X,Y))).

//---------------------------------------END OF SIM----------------------------------------//

+end_of_simulation(S,R)
  <- .drop_all_desires;
     !remove(gold(_,_));
     .abolish(picked(_));

     -+search_gold_strategy(near_unvisited);
     .abolish(quadrant(X1,Y1,X2,Y2));
     .abolish(last_checked(_,_));

     -+free;

     .print("-- END ",S,": ",R).


+!remove(gold(X,Y))
  <- .abolish(gold(X,Y));
     .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y)));
     .abolish(announced(gold(X,Y)));
     .abolish(allocated(gold(X,Y),_)).


//------------------------------------RESET MINER-------------------------------------//
@rl[atomic]
+restart
  <- .print("*** Start it all again!");
     .drop_all_desires;
     !choose_goal.

@committed_handling[atomic]
+committed_to(gold(GX,GY),Dist,A)
  :  .desire(fetch_gold(gold(GX,GY))) &
     .my_name(MyName) & MyName \== A &
     A \== none &
     pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,GX,GY,MyDist) &
     MyDist > Dist + 5  // Only give up if other agent is significantly closer
  <- .print("=== Yielding gold at [", GX, ",", GY, "] to closer agent ", A);
     .drop_desire(fetch_gold(gold(GX,GY)));
     !choose_goal.