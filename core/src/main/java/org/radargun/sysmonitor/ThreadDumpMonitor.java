package org.radargun.sysmonitor;

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.management.LockInfo;
import java.lang.management.MonitorInfo;
import java.lang.management.ThreadInfo;
import java.lang.management.ThreadMXBean;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import org.radargun.reporting.Timeline;
import org.radargun.traits.JmxConnectionProvider;

import static java.lang.management.ManagementFactory.THREAD_MXBEAN_NAME;
import static java.lang.management.ManagementFactory.newPlatformMXBeanProxy;

public class ThreadDumpMonitor extends JmxMonitor {

   private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd_HH:mm:ss");

   private ThreadMXBean threadMXBean;
   private final boolean lockedMonitors;
   private final boolean lockedSynchronizers;
   private final int workerIndex;


   public ThreadDumpMonitor(JmxConnectionProvider jmxConnectionProvider, Timeline timeline,
                            boolean dumpThreadLockedMonitors, boolean dumpThreadLockedSynchronizers, int workerIndex) {
      super(jmxConnectionProvider, timeline);
      this.lockedMonitors = dumpThreadLockedMonitors;
      this.lockedSynchronizers = dumpThreadLockedSynchronizers;
      this.workerIndex = workerIndex;
   }

   public synchronized void runMonitor() {
      try {
         if (connection == null) {
            log.warn("MBean connection is not open, cannot read Thread Dump");
            return;
         }
         threadDump();
      } catch (Exception e) {
         log.error("Exception!", e);
      }
   }

   @Override
   public synchronized void start() {
      super.start();
      try {
         this.threadMXBean = newPlatformMXBeanProxy(connection, THREAD_MXBEAN_NAME, ThreadMXBean.class);
      } catch (IOException e) {
         throw new IllegalStateException("Cannot create threadMXBean", e);
      }
   }

   @Override
   public synchronized void stop() {
      super.stop();
   }

   public void threadDump() {
      log.info("Generating thread dump for: " + this.workerIndex);

      String fileName = String.format("thread-dump-worker-%s-%s.dump", this.workerIndex, DATE_FORMATTER.format(LocalDateTime.now()));
      final ThreadInfo[] threadInfos = threadMXBean.getThreadInfo(threadMXBean.getAllThreadIds(), 100);
      try (BufferedWriter writer = new BufferedWriter(new FileWriter(fileName, true))){
         for (ThreadInfo threadInfo : threadInfos) {
            writer.append(threadInfoToString(threadInfo));
         }
      } catch (IOException e) {
         log.error("Error while generating thread dump", e);
      }

      log.info("Thread dump generated for: " + this.workerIndex);
   }

   // copied from ThreadInfo without the MAX_FRAMES restrictions.
   public String threadInfoToString(ThreadInfo threadInfo) {
      StringBuilder sb = new StringBuilder("\"" + threadInfo.getThreadName() + "\"" +
            " Id=" + threadInfo.getThreadId() + " " +
            threadInfo.getThreadState());
      if (threadInfo.getLockName() != null) {
         sb.append(" on " + threadInfo.getLockName());
      }
      if (threadInfo.getLockOwnerName() != null) {
         sb.append(" owned by \"" + threadInfo.getLockOwnerName() +
               "\" Id=" + threadInfo.getLockOwnerId());
      }
      if (threadInfo.isSuspended()) {
         sb.append(" (suspended)");
      }
      if (threadInfo.isInNative()) {
         sb.append(" (in native)");
      }
      sb.append('\n');
      int i = 0;
      final StackTraceElement[] stackTrace = threadInfo.getStackTrace();
      for (; i < stackTrace.length && i < stackTrace.length; i++) {
         StackTraceElement ste = stackTrace[i];
         sb.append("\tat " + ste.toString());
         sb.append('\n');
         if (i == 0 && threadInfo.getLockInfo() != null) {
            Thread.State ts = threadInfo.getThreadState();
            switch (ts) {
               case BLOCKED:
                  sb.append("\t-  blocked on " + threadInfo.getLockInfo());
                  sb.append('\n');
                  break;
               case WAITING:
                  sb.append("\t-  waiting on " + threadInfo.getLockInfo());
                  sb.append('\n');
                  break;
               case TIMED_WAITING:
                  sb.append("\t-  waiting on " + threadInfo.getLockInfo());
                  sb.append('\n');
                  break;
               default:
            }
         }
         for (MonitorInfo mi : threadInfo.getLockedMonitors()) {
            if (mi.getLockedStackDepth() == i) {
               sb.append("\t-  locked " + mi);
               sb.append('\n');
            }
         }
      }

      LockInfo[] locks = threadInfo.getLockedSynchronizers();
      if (locks.length > 0) {
         sb.append("\n\tNumber of locked synchronizers = " + locks.length);
         sb.append('\n');
         for (LockInfo li : locks) {
            sb.append("\t- " + li);
            sb.append('\n');
         }
      }
      sb.append('\n');
      return sb.toString();
   }
}
