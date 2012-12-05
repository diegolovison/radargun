/* 
 * JBoss, Home of Professional Open Source
 * Copyright 2012 Red Hat Inc. and/or its affiliates and other contributors
 * as indicated by the @author tags. All rights reserved.
 * See the copyright.txt in the distribution for a
 * full listing of individual contributors.
 *
 * This copyrighted material is made available to anyone wishing to use,
 * modify, copy, or redistribute it subject to the terms and conditions
 * of the GNU Lesser General Public License, v. 2.1.
 * This program is distributed in the hope that it will be useful, but WITHOUT A
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more details.
 * You should have received a copy of the GNU Lesser General Public License,
 * v.2.1 along with this distribution; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA  02110-1301, USA.
 */
package org.radargun.stages;

import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.radargun.DistStageAck;

import java.util.HashMap;
import java.util.Map;
import java.util.Stack;

public class SetLogLevelStage extends AbstractDistStage {

   private String pkg;
   private String priority;
   private boolean pop;

   private static Map<String, Stack<Level>> stacks = new HashMap<String, Stack<Level>>();

   @Override
   public DistStageAck executeOnSlave() {
      try {
         Stack<Level> stack = stacks.get(pkg);
         if (stack == null) {
            stack = new Stack<Level>();
            stacks.put(pkg, stack);
         }
         if (priority != null) {
            stack.push(Logger.getLogger(pkg).getLevel());
            Logger.getLogger(pkg).setLevel(Level.toLevel(priority));
         } else if (pop) {
            if (stack.empty()) {
               log.error("Cannot POP priority level, stack empty!");
            } else {
               Logger.getLogger(pkg).setLevel(stack.pop());
            }
         } else {
            log.error("Neither priority nor POP request specified");
         }
      } catch (Exception e) {
         log.error("Failed to change log level", e);
      }
      return newDefaultStageAck();
   }

   public void setPackage(String pkg) {
      this.pkg = pkg;
   }

   public void setPriority(String priority) {
      this.priority = priority;
   }
   
   @Override
   public String toString() {
	   return "SetLogLevel(package=" + pkg + ", priority=" + Level.toLevel(priority).toString() + ", " + super.toString();
   }

   public void setPop(boolean pop) {
      this.pop = pop;
   }
}