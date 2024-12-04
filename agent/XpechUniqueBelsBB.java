package agent;

import jason.asSemantics.Agent;
import jason.asSemantics.Unifier;
import jason.asSyntax.Literal;
import jason.asSyntax.Term;
import jason.bb.DefaultBeliefBase;

import jason.asSemantics.Unifier;
import java.util.*;
import java.util.stream.Collectors;


public class XpechUniqueBelsBB extends DefaultBeliefBase {
    private Map<String, Set<String>> uniqueKeyFields = new HashMap<>();
    private Unifier u = new Unifier(); // Explicitly declare the Unifier

    public void init(Agent ag, String[] args) {
        // Define fields that should be unique across belief types
        uniqueKeyFields.put("gold", new HashSet<>(Arrays.asList("0", "1"))); // x, y coordinates
        uniqueKeyFields.put("committed_to", new HashSet<>(Arrays.asList("0"))); // gold location
        uniqueKeyFields.put("depot", new HashSet<>(Arrays.asList("0"))); // scenario identifier
    }

   @Override
public boolean add(Literal bel) {
    try {
        String functor = bel.getFunctor();
        if (uniqueKeyFields.containsKey(functor)) {
            Set<String> keyIndexes = uniqueKeyFields.get(functor);
            
            Iterator<Literal> existing = getCandidateBeliefs(bel, null);
            while (existing != null && existing.hasNext()) {
                Literal existingBel = existing.next();
                boolean shouldReplace = true;
                
                for (int keyIndex : keyIndexes.stream().mapToInt(Integer::parseInt).toArray()) {
                    if (!u.unifies(bel.getTerm(keyIndex), existingBel.getTerm(keyIndex))) {
                        shouldReplace = false;
                        break;
                    }
                }
                
                if (shouldReplace) {
                    remove(existingBel);
                    break;
                }
            }
        }
        
        return super.add(bel);
    } catch (Exception e) {
        e.printStackTrace();
        return false;
    }
}
}