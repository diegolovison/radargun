package org.radargun.stages.test;

import java.util.Random;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.LockSupport;

import org.radargun.Operation;
import org.radargun.logging.Log;
import org.radargun.logging.LogFactory;
import org.radargun.stats.Request;
import org.radargun.stats.RequestSet;
import org.radargun.stats.Statistics;
import org.radargun.traits.OverallOperation;
import org.radargun.traits.Transactional;
import org.radargun.utils.TimeService;

/**
 * Each stressor operates according to its {@link OperationLogic logic} - the instance is private to each thread.
 * After finishing the {@linkplain OperationLogic#init(Stressor) init phase}, all stressors synchronously
 * execute logic's {@link OperationLogic#run(org.radargun.Operation) run} method until
 * the {@link Completion#moreToRun()} returns false.
 *
 * @author Radim Vansa &lt;rvansa@redhat.com&gt;
 */
public class Stressor extends Thread {
   private static Log log = LogFactory.getLog(Stressor.class);

   private final TestStage stage;
   private final int threadIndex;
   private final int globalThreadIndex;
   private final OperationLogic logic;
   private final Random random;
   private final OperationSelector operationSelector;
   private final Completion completion;
   private final boolean logTransactionExceptions;
   private long thinkTime;

   private boolean useTransactions;
   private int txRemainingOperations = 0;
   private RequestSet requests;
   private Transactional.Transaction ongoingTx;
   private Statistics stats;
   private boolean started = false;
   private CountDownLatch threadCountDown;

   // uniform rate limiter
   final long uniformRateLimiterOpsPerNano;
   long uniformRateLimiterOpIndex = 0;
   long uniformRateLimiterStart = Long.MIN_VALUE;

   public Stressor(TestStage stage, OperationLogic logic, int globalThreadIndex, int threadIndex, CountDownLatch threadCountDown) {
      super("Stressor-" + threadIndex);
      this.stage = stage;
      this.threadIndex = threadIndex;
      this.globalThreadIndex = globalThreadIndex;
      this.logic = logic;
      this.random = ThreadLocalRandom.current();
      this.completion = stage.getCompletion();
      this.operationSelector = stage.getOperationSelector();
      this.logTransactionExceptions = stage.logTransactionExceptions;
      this.threadCountDown = threadCountDown;
      this.thinkTime = stage.thinkTime;
      this.uniformRateLimiterOpsPerNano = TimeUnit.MILLISECONDS.toNanos(stage.cycleTime);
   }

   private boolean recording() {
      return this.started && !stage.isFinished();
   }

   @Override
   public void run() {
      try {
         logic.init(this);
         stats = stage.createStatistics();

         runInternal();

      } catch (Exception e) {
         log.error("Unexpected error in stressor!", e);
         stage.setTerminated();
      } finally {
         if (stats != null) {
            stats.end();
         }
         logic.destroy();
      }
   }

   private void runInternal() {
      boolean counted = false;
      try {
         // the operation selector needs to be started before any #next() call
         operationSelector.start();

         while (!stage.isTerminated()) {
            boolean started = stage.isStarted();
            if (started) {
               txRemainingOperations = 0;
               if (ongoingTx != null) {
                  endTransactionAndRegisterStats();
               }
               break;
            } else {
               if (!counted) {
                  threadCountDown.countDown();
                  counted = true;
               }
               Operation operation = operationSelector.next(random);
               try {
                  logic.run(operation);
                  if (thinkTime > 0)
                     sleep(thinkTime);
               } catch (OperationLogic.RequestException e) {
                  // the exception was already logged in makeRequest
               } catch (InterruptedException e) {
                  log.trace("Stressor interrupted.", e);
                  interrupt();
               }
            }
         }

         uniformRateLimiterStart = TimeService.nanoTime();
         stats.begin();
         this.started = true;
         completion.start();
         int i = 0;
         while (!stage.isTerminated()) {
            Operation operation = operationSelector.next(random);
            if (!completion.moreToRun()) break;
            try {
               logic.run(operation);
               if (thinkTime > 0)
                  sleep(thinkTime);
            } catch (OperationLogic.RequestException e) {
               // the exception was already logged in makeRequest
            } catch (InterruptedException e) {
               log.trace("Stressor interrupted.", e);
               interrupt();
            }
            i++;
            completion.logProgress(i);
         }
      } finally {
         if (txRemainingOperations > 0) {
            endTransactionAndRegisterStats();
         }
      }
   }

   public <T> T wrap(T resource) {
      return ongoingTx.wrap(resource);
   }

   public <T> T makeRequest(Invocation<T> invocation) throws OperationLogic.RequestException {
      return makeRequest(invocation, true);
   }

   public <T> T makeRequest(Invocation<T> invocation, boolean countForTx) throws OperationLogic.RequestException {

      T result = null;
      try {
         if (recording()) {
            requests = stats.requestSet();
            Request beginOperation = enqueueRequest();
            beginOperation.succeeded(OverallOperation.BEGIN);
            requests.add(beginOperation);
         }

         if (recording() && requests != null && useTransactions && txRemainingOperations <= 0) {
            try {
               ongoingTx = stage.transactional.getTransaction();
               logic.transactionStarted();
               Request beginTransactionRequest = startTransaction();
               if (requests != null && beginTransactionRequest != null) {
                  requests.add(beginTransactionRequest);
               }
               txRemainingOperations = stage.transactionSize;
            } catch (TransactionException e) {
               throw new OperationLogic.RequestException(e);
            }
         }

         Request request = null;
         if (recording() && requests != null) {
            Exception exception = null;
            request = stats.startRequest();
            Operation operation = invocation.operation();
            try {
               result = invocation.invoke();
               succeeded(request, operation);
               // make sure that the return value cannot be optimized away
               // however, we can't be 100% sure about reordering without
               // volatile writes/reads here
               Blackhole.consume(result);
               if (countForTx) {
                  txRemainingOperations--;
               }
            } catch (Exception e) {
               failed(request, operation);
               log.warn("Error in request", e);
               txRemainingOperations = 0;
               exception = e;
            }
            if (exception != null) {
               throw new OperationLogic.RequestException(exception);
            }
            requests.add(request);
         }

         if (recording() && requests != null && request != null) {
            if (useTransactions && txRemainingOperations <= 0) {
               Request commitRequest = endTransactionAndRegisterStats();
               requests.add(commitRequest);
               requests.finished(commitRequest.isSuccessful(), Transactional.DURATION);
               requests.finished(commitRequest.isSuccessful(), OverallOperation.DURATION);
            } else {
               requests.finished(request.isSuccessful(), OverallOperation.DURATION);
            }
         } else {
            if (requests != null) {
               requests.discard();
            }
         }
      } finally {
         requests = null;
      }
      return result;
   }

   public <T> void succeeded(Request request, Operation operation) {
      if (request != null) {
         if (recording()) {
            request.succeeded(operation);
         } else {
            request.discard();
         }
      }
   }

   public <T> void failed(Request request, Operation operation) {
      if (request != null) {
         if (recording()) {
            request.failed(operation);
         } else {
            request.discard();
         }
      }
   }

   private Request endTransactionAndRegisterStats() {
      Request commitRequest = stats.startRequest();
      try {
         if (stage.commitTransactions) {
            ongoingTx.commit();
         } else {
            ongoingTx.rollback();
         }
         succeeded(commitRequest, stage.commitTransactions ? Transactional.COMMIT : Transactional.ROLLBACK);
      } catch (Exception e) {
         failed(commitRequest, stage.commitTransactions ? Transactional.COMMIT : Transactional.ROLLBACK);
         if (logTransactionExceptions) {
            log.error("Failed to end transaction", e);
         }
      } finally {
         clearTransaction();
      }
      return commitRequest;
   }

   public void setUseTransactions(boolean useTransactions) {
      this.useTransactions = useTransactions;
   }

   private void clearTransaction() {
      logic.transactionEnded();
      ongoingTx = null;
   }

   public int getThreadIndex() {
      return threadIndex;
   }

   public int getGlobalThreadIndex() {
      return globalThreadIndex;
   }

   public Statistics getStats() {
      return stats;
   }

   public OperationLogic getLogic() {
      return logic;
   }

   public Random getRandom() {
      return random;
   }

   public boolean isUseTransactions() {
      return useTransactions;
   }

   private Request startTransaction() throws TransactionException {
      Request request = stats.startRequest();
      try {
         ongoingTx.begin();
         request.succeeded(Transactional.BEGIN);
         return request;
      } catch (Exception e) {
         request.failed(Transactional.BEGIN);
         log.error("Failed to start transaction", e);
         throw new TransactionException(request, e);
      }
   }

   private class TransactionException extends Exception {
      private final Request request;

      public TransactionException(Request request, Exception cause) {
         super(cause);
         this.request = request;
      }

      public Request getRequest() {
         return request;
      }
   }

   private Request enqueueRequest() {
      Request request;
      if (uniformRateLimiterOpsPerNano > 0) {
         request = stats.startRequest(uniformRateLimiterStart + (++uniformRateLimiterOpIndex) * uniformRateLimiterOpsPerNano);
         long intendedTime = request.getRequestStartTime();
         long now;
         while ((now = System.nanoTime()) < intendedTime)
            LockSupport.parkNanos(intendedTime - now);
      } else {
         request = stats.startRequest();
      }
      return request;
   }
}
