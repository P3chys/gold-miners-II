// Hyper-aggressive miner agent focused on immediate gold collection

{ include("moving.asl") }
{ include("search_unvisited.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("allocation_protocol.asl") }

/* functions */
{ register_function("carrying.gold",0,"carrying_gold") }
{ register_function("jia.path_length",4,"jia.path_length") }

//----------------------------------------BELIEFS--------------------------------//
free.
my_capacity(3).
last_success(none, none).  // Remember last successful gold location
area_failed_cycles(0).    // Track how long we've been unsuccessful in an area

//----------------------------------------INIT----------------------------------------//
+pos(_,_,0)
  <- ?gsize(S,_,_);
     .print("=== AGGRESSIVE MINER INITIALIZED ===");
     !inform_gsize_to_leader(S);
     !choose_goal.

+!inform_gsize_to_leader(S) : .my_name(miner1)
   <- ?depot(S,DX,DY);
      .send(leader,tell,depot(S,DX,DY));
      ?gsize(S,W,H);
      .send(leader,tell,gsize(S,W,H)).
+!inform_gsize_to_leader(_).

//----------------------------------------FAILED AREA HANDLING----------------------------------------//
+!check_area_productivity
  :  area_failed_cycles(N) & N > 15 &    // If no gold found for 15 cycles
     .findall(gold(X,Y), gold(X,Y), GoldList) &
     GoldList \== [] 
  <- .print("=== Area unproductive, moving towards known gold");
     .random(GoldList, gold(TargetX,TargetY));  // Pick random known gold
     !goto_near(TargetX,TargetY).

+!goto_near(X,Y)
  :  pos(AgX,AgY,_)
  <- RX = math.random(8) - 4;   // Random offset near target
     RY = math.random(8) - 4;
     NewX = X + RX;
     NewY = Y + RY;
     -+area_failed_cycles(0);    // Reset counter
     !goto(NewX,NewY).

// Update cycle counter when moving without finding gold
+step(S)
  :  not .desire(quick_fetch(_))
  <- ?area_failed_cycles(N);
     -+area_failed_cycles(N+1);
     if (N+1 mod 5 == 0) {
         !check_area_productivity;
     }.

// Reset counter when finding gold
+cell(X,Y,gold)
  <- -+area_failed_cycles(0).

//----------------------------------------EMERGENCY DEPOT RETURN----------------------------------------//
// Super aggressive depot return timing - don't risk losing gold
should_return_to_depot :- carrying_gold(3).
should_return_to_depot :- 
    carrying_gold(N) & N > 0 & 
    pos(_,_,Step) & 
    steps(_,TotalSteps) & 
    Step + 70 > TotalSteps.  // Even earlier return than dummy

//----------------------------------------IMMEDIATE GOLD GRABBING----------------------------------------//
// Highest priority - Immediate response to seeing gold
@gold_spotted[atomic]
+cell(GX,GY,gold)
  :  carrying_gold(N) & N < 3 &
     pos(X,Y,_)
  <- .print("=== GOLD SPOTTED! Moving to [", GX, ",", GY, "]");
     .drop_all_desires;  // Drop everything immediately
     -+last_success(GX,GY);  // Remember this spot
     !quick_fetch(gold(GX,GY)).

// Direct movement to gold - minimal computation
+!quick_fetch(gold(GX,GY))
  :  pos(X,Y,_) &
     not should_return_to_depot
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

// If should return to depot while fetching, do it immediately
+!quick_fetch(gold(GX,GY))
  :  should_return_to_depot
  <- !emergency_depot_return.

//----------------------------------------AGGRESSIVE DEPOT RETURN----------------------------------------//
+!emergency_depot_return
  :  pos(X,Y,_) &
     depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

//----------------------------------------AGGRESSIVE SEARCH----------------------------------------//
// Search near last successful location first
+!choose_goal
  :  should_return_to_depot
  <- !emergency_depot_return.

+!choose_goal
  :  last_success(X,Y) & X \== none &
     pos(AgX,AgY,_)
  <- RX = math.random(10) - 5;
     RY = math.random(10) - 5;
     NewX = X + RX;
     NewY = Y + RY;
     !goto(NewX,NewY).

+!choose_goal
  :  pos(AgX,AgY,_)
  <- RX = math.random(20) - 10;
     RY = math.random(20) - 10;
     NewX = AgX + RX;
     NewY = AgY + RY;
     !goto(NewX,NewY).

+!choose_goal
  :  not gold(_,_) &         // No gold in sight
     area_failed_cycles(N) & N > 15 &
     .findall(gold(X,Y), gold(X,Y), GoldList) &
     GoldList \== []
  <- !check_area_productivity.

+!choose_goal // not carrying gold, be free and search gold
   <- RX = math.random(20) - 10;
      RY = math.random(20) - 10;
      !goto(RX,RY).
//----------------------------------------COORDINATE WITH OTHERS----------------------------------------//
// Share gold findings but don't waste time on complex coordination
+gold(X,Y)[source(A)]
  :  carrying_gold(N) & N < 3 &
     pos(AgX,AgY,_)
  <- !quick_fetch(gold(X,Y)).

// Basic information sharing
+request_gold_info[source(Miner)]
  <- .findall(gold(X,Y), gold(X,Y), GoldList);
     .send(Miner, tell, known_golds(GoldList)).

//----------------------------------------CLEANUP----------------------------------------//
+end_of_simulation(S,R)
  <- .drop_all_desires;
     -+last_success(none, none);
     .print("-- END ",S,": ",R).

@rl[atomic]
+restart
  <- .print("*** Starting fresh ***");
     .drop_all_desires;
     -+last_success(none, none);
     !choose_goal.