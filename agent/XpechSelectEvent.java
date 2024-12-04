
package agent;

import jason.asSemantics.Agent;
import jason.asSemantics.Event;
import jason.asSemantics.Unifier;
import jason.asSyntax.Trigger;

import java.util.Iterator;
import java.util.Queue;

/**
 * change the default select event function to prefer cell(_,_,gold) events.
 *
 * @author Jomi
 */
public class XpechSelectEvent extends Agent {

    private Trigger gold    = Trigger.parseTrigger("+cell(_,_,gold)");
    private Trigger restart = Trigger.parseTrigger("+restart");
    private Unifier un   = new Unifier();

    public Event selectEvent(Queue<Event> events) {
    Iterator<Event> ie = events.iterator();
    
    // Prioritize gold, restart, and critical events in that order
    Trigger[] criticalTriggers = {
        Trigger.parseTrigger("+cell(_,_,gold)"),
        Trigger.parseTrigger("+restart"),
        Trigger.parseTrigger("+end_of_simulation(_,_)"),
        Trigger.parseTrigger("+committed_to(_,_,_)")
    };

    for (Trigger criticalTrigger : criticalTriggers) {
        ie = events.iterator();
        while (ie.hasNext()) {
            un.clear();
            Event e = ie.next();
            if (un.unifies(criticalTrigger, e.getTrigger())) {
                ie.remove();
                return e;
            }
        }
    }
    
    return super.selectEvent(events);
}


}
