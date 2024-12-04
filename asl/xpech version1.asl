// Enhanced miner agent with advanced navigation and strategy
// Combines obstacle avoidance, quadrant exploration, and intelligent gold evaluation

{ include("moving.asl") }
{ include("search_unvisited.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("allocation_protocol.asl") }

/* Function Registration */
{ register_function("carrying.gold",0,"carrying_gold") }
{ register_function("jia.path_length",4,"jia.path_length") }

/* Initial Beliefs and Rules */
free.
my_capacity(3).
quadrant_exploration_timeout(100).  // cycles before changing quadrant

/* Navigation and Obstacle Management */
+obstacle(X,Y) 
  <- .print("=== Found obstacle at [", X, ",", Y, "]");
     +blocked_path(X,Y).

// Global path mapping
+!map_navigation_paths
  :  gsize(S,W,H)
  <- .print("=== Mapping navigation paths for size: ", W, "x", H);
     .findall(gap(X1,Y1,X2,Y2), 
              (blocked_path(X1,Y1) & 
               not blocked_path(X2,Y2) & 
               adjacent(X1,Y1,X2,Y2)), 
              Gaps);
     .print("=== Found gaps: ", Gaps);
     +navigation_paths(Gaps).

// Adjacent cells check
adjacent(X1,Y1,X2,Y2) :- 
   (X2 = X1+1 & Y1 = Y2) | 
   (X2 = X1-1 & Y1 = Y2) | 
   (Y2 = Y1+1 & X1 = X2) | 
   (Y2 = Y1-1 & X1 = X2).

/* Quadrant Management */
+!track_quadrant_exploration
  :  quadrant(X1,Y1,X2,Y2) &
     steps(_,CurrentStep)
  <- .print("=== Starting exploration of quadrant [", X1, ",", Y1, ",", X2, ",", Y2, "] at step ", CurrentStep);
     +quadrant_exploration_start(CurrentStep).

+!check_quadrant_exploration
  :  quadrant_exploration_start(StartStep) &
     steps(_,CurrentStep) &
     quadrant_exploration_timeout(Timeout) &
     CurrentStep - StartStep > Timeout
  <- .print("=== Quadrant exploration timeout reached");
     !change_quadrant.

+!change_quadrant
  :  gsize(S,W,H) &
     quadrant(OldX1,OldY1,OldX2,OldY2)
  <- .random(R1);
     .random(R2);
     NewX1 = math.floor(R1 * W);
     NewY1 = math.floor(R2 * H);
     .print("=== Changing quadrant from [", OldX1, ",", OldY1, ",", OldX2, ",", OldY2, 
            "] to [", NewX1, ",", NewY1, ",", NewX1+math.floor(W/2), ",", NewY1+math.floor(H/2), "]");
     !search_quadrant(NewX1, NewY1, 
                     NewX1+math.floor(W/2), 
                     NewY1+math.floor(H/2));
     -quadrant_exploration_start(_);
     steps(_,CurrentStep);
     +quadrant_exploration_start(CurrentStep).

/* Enhanced Movement Planning */
+!move(X,Y)
  :  navigation_paths(Gaps) & 
     .member(gap(GapX1,GapY1,GapX2,GapY2), Gaps)
  <- .print("=== Moving through gap from [", GapX1, ",", GapY1, "] to [", GapX2, ",", GapY2, "]");
     !goto(GapX2,GapY2).

+!move(X,Y)
  :  pos(CurX,CurY,_)
  <- .print("=== Regular movement to [", X, ",", Y, "]");
     +blocked_path(CurX,CurY);
     !goto(X,Y).

/* Initialization and Strategy Selection */
search_gold_strategy(near_unvisited).

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .print("========== ENHANCED MINER INITIALIZED ==========");
     .print("Starting simulation ", S);
     !inform_gsize_to_leader(S);
     !map_navigation_paths;
     !choose_goal.
/* Goal Selection Plans */
@cgod2[atomic]
+!choose_goal
 :  container_has_space &               
    .findall(gold(X,Y),gold(X,Y),LG) &  
    evaluate_golds(LG,LD) &             
    .print("All golds=",LG,", evaluation=",LD) &
    .length(LD) > 0 &                   
    .min(LD,d(D,NewG,_)) &              
    worthwhile(NewG)
 <- .print("Gold options are ",LD,". Next gold is ",NewG);
    !change_to_fetch(NewG).

+!choose_goal 
  :  carrying_gold(NG) & NG > 0
  <- !change_to_goto_depot.

+!choose_goal 
  <- !change_to_search.

/* Goal Transition Plans */
+!change_to_goto_depot             
  :  .desire(goto_depot)
  <- .print("=== Already going to depot").

+!change_to_goto_depot             
  :  .desire(fetch_gold(G))
  <- .print("=== Dropping fetch gold goal to go to depot");
     .drop_desire(fetch_gold(G));
     !change_to_goto_depot.

+!change_to_goto_depot             
  <- .print("=== Changing goal to goto depot");
     -free;
     !!goto_depot.

+!change_to_fetch(G)               
  :  .desire(fetch_gold(G))
  <- .print("=== Already fetching gold ", G).

+!change_to_fetch(G)               
  :  .desire(goto_depot)
  <- .print("=== Dropping goto depot to fetch gold ", G);
     .drop_desire(goto_depot);
     !change_to_fetch(G).

+!change_to_fetch(G)               
  :  .desire(fetch_gold(OtherG))
  <- .print("=== Changing fetch target from ", OtherG, " to ", G);
     .drop_desire(fetch_gold(OtherG));
     !change_to_fetch(G).

+!change_to_fetch(G)                
  <- .print("=== Changing goal to fetch gold ", G);
     -free;
     !!fetch_gold(G).

+!change_to_search
  :  search_gold_strategy(S)
  <- .print("=== New goal: search gold using strategy ", S);
     -free;
     +free;
     .drop_all_desires;
     !!search_gold(S).

/* Gold Evaluation Helper */
evaluate_golds([],[]).
evaluate_golds([gold(GX, GY)|R],[d(U,gold(GX,GY),Annot)|RD])
  .evaluate_gold(gold(GX,GY),U,Annot);
     evaluate_golds(R,RD).
evaluate_golds([_|R],RD)
  : evaluate_golds(R,RD).

/* Gold Evaluation */
evaluate_gold(gold(X,Y),Utility,Annot)
  :- pos(AgX,AgY,_) & 
     jia.path_length(AgX,AgY,X,Y,PathLength) &
     .print("=== Evaluating gold at [", X, ",", Y, "]") &
     calculate_gold_utility(PathLength, X, Y, Utility) &
     .print("=== Calculated utility: ", Utility) &
     check_commit(gold(X,Y),Utility,Annot).

calculate_gold_utility(PathLength, GoldX, GoldY, Utility)
  :- pos(AgX,AgY,_) &
     depot(_,DepotX,DepotY) &
     jia.path_length(GoldX,GoldY,DepotX,DepotY,DepotDistance) &
     jia.add_fatigue(PathLength, BaseFatigue) &
     
     // Strategic scoring
     PathPenalty = BaseFatigue * 10.0 &
     DepotBonus = (100 - DepotDistance) / 10.0 &
     
     // Final calculation
     Utility = PathPenalty - DepotBonus &
     
     // Debug info
     .print("=== Utility calculation:") &
     .print("    Path Length: ", PathLength) &
     .print("    Base Fatigue: ", BaseFatigue) &
     .print("    Path Penalty: ", PathPenalty) &
     .print("    Depot Distance: ", DepotDistance) &
     .print("    Depot Bonus: ", DepotBonus) &
     .print("    Final Utility: ", Utility).

/* Dynamic Strategy Adjustment */
+!adjust_search_strategy
  :  carrying_gold(0) & 
     .count(gold(_,_)) == 0
  <- .print("=== Strategy Change: Switching to quadrant search");
     -+search_gold_strategy(quadrant).

+!adjust_search_strategy
  :  .count(gold(_,_)) > 3
  <- .print("=== Strategy Change: Switching to near unvisited");
     -+search_gold_strategy(near_unvisited).

/* Periodic Checks */
+step(S) 
  :  S mod 10 == 0 
  <- !check_quadrant_exploration;
     !adjust_search_strategy.

/* Enhanced worthwhile calculation */
worthwhile(gold(_,_)) :- carrying_gold(0).
worthwhile(gold(GX,GY)) :-
     carrying_gold(NG) & NG > 0 &
     pos(AgX,AgY,Step) &
     depot(_,DX,DY) &
     steps(_,TotalSteps) &
     AvailableSteps = TotalSteps - Step &
     
     // Path calculations
     jia.add_fatigue(jia.path_length(AgX,AgY,GX,GY),NG,  PathToGold) &
     jia.add_fatigue(jia.path_length(GX,GY,DX,DY),NG+1,PathToDepot) &
     
     // Strategic decision making
     TotalPathCost = PathToGold + PathToDepot &
     MarginFactor = 1.5 &
     AvailableSteps > (TotalPathCost * MarginFactor) &
     
     // Debug output
     .print("=== Worthwhile check for gold at [", GX, ",", GY, "]:") &
     .print("    Carrying: ", NG, " gold") &
     .print("    Available Steps: ", AvailableSteps) &
     .print("    Total Path Cost: ", TotalPathCost) &
     .print("    Required Steps: ", TotalPathCost * MarginFactor).

/* Event Handling */
+cell(X,Y,gold)
  :  container_has_space &
     not gold(X,Y)
  <- .print("=== New gold discovered at [", X, ",", Y, "]");
     +gold(X,Y);
     !choose_goal.

+cell(X,Y,gold)
  :  not container_has_space & 
     not gold(X,Y) & 
     not committed(gold(X,Y),_,_)
  <- .print("=== Broadcasting gold location at [", X, ",", Y, "]");
     +gold(X,Y);
     +announced(gold(X,Y));
     .broadcast(tell,gold(X,Y)).

+cell(X,Y,empty)
  :  gold(X,Y) &
     not .desire(fetch_gold(gold(X,Y)))
  <- .print("=== Gold depleted at [", X, ",", Y, "]");
     !remove(gold(X,Y));
     .broadcast(tell,picked(gold(X,Y))).

/* Simulation Management */
+end_of_simulation(S,R)
  <- .print("=== End of simulation ", S, ": ", R);
     .drop_all_desires;
     !remove(gold(_,_));
     .abolish(picked(_));
     .abolish(blocked_path(_,_));
     .abolish(navigation_paths(_));
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     .abolish(quadrant_exploration_start(_));
     -+search_gold_strategy(near_unvisited);
     -+free.