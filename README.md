3 custom miner types
files named:   /asl/miner.asl - latest and best
               /asl/xpech.asl - second iteration
               /asl/xpech version 1.asl - first iteration

another customized files:
              leader.asl
              /agent/XpechDiscardBelsBB.java
              /agent/XpechSelectEvent.java
              /agent/XpechUniqueBelsBB.java
              miners.mas2j





Each generation of miner has it's own flaws and wins, it can pretty consistently win against dummy but the result depends on spawn locations and mostly first 100 cycles.
To switch between miner generations change them in miners.mas2j and leader.asl or simpler just rename desired file to miner.asl.

Code was run on java version "21.0.5" 2024-10-15 LTS and Gradle 8.11.1.

To start whole project gradle run in root directory.
