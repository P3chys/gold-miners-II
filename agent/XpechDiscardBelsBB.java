package agent;

import jason.asSemantics.Agent;
import jason.asSyntax.Literal;
import jason.bb.DefaultBeliefBase;

import java.util.HashSet;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;


/**
 * Customised version of Belief Base where some beliefs are discarded.
 * E.g.:<br/>
 * <code>ag1 beliefBaseClass agent.DiscardBelsBB("my_status","picked");</code>
 * <br/>
 * will discard all addition of beliefs with my_status or picked functor.
 *
 * @author jomi
 */
public class XpechDiscardBelsBB extends DefaultBeliefBase {
    protected Logger logger = Logger.getLogger(XpechDiscardBelsBB.class.getName());
    //static private Logger logger = Logger.getLogger(UniqueBelsBB.class.getName());

    Set<String> discartedBels = new HashSet<String>();

    public void init(Agent ag, String[] args) {
        for (int i=0; i<args.length; i++) {
            discartedBels.add(args[i]);
        }
    }

    @Override
    public boolean add(Literal bel){
        logger.info("Error in restart!");
       try {
        return super.add(bel);
    } catch(Exception e){
         e.printStackTrace();
        return false;
    }
    }
}
