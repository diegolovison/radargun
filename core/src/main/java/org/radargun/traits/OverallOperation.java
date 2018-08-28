package org.radargun.traits;

import org.radargun.Operation;

/**
 * Overall Operation
 *
 * @author Diego Lovison &lt;dlovison@redhat.com&gt;
 */
public interface OverallOperation {
   String TRAIT = OverallOperation.class.getSimpleName();
   /**
    * In order to avoid adding a delay in a real operation. Begin will have the response time equals the amount of the
    * time in the queue.
    */
   Operation BEGIN = Operation.register(TRAIT + ".Begin");

   /**
    * Duration is used to show in the chart a comparison between all benchmarks tests.
    */
   Operation DURATION = Operation.register(TRAIT + ".Duration");
}
