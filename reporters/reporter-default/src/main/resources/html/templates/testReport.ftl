<html xmlns="http://www.w3.org/1999/html">
<head>
    <title>${testReport.getTitle()}</title>
    <link rel="stylesheet" href="${staticHost}style.css">
    <link rel="stylesheet" href="${staticHost}c3.css">
    <#import "lib/library.ftl" as library />
    <script src="${staticHost}script.js"></script>
    <script src="${staticHost}d3.v3.min.js"></script>
    <script src="${staticHost}c3.min.js"></script>
</head>
<body>
  <h1>Test ${testReport.getTestName()}</h1>
  <#assign StatisticType=enums["org.radargun.reporting.html.ReportDocument$StatisticType"] />

  <#-- counter from creating unique classes for hidden rows -->
  <#assign hiddenCounter = 0>

  <#list  testReport.getTestAggregations() as aggregations>
    <#list aggregations.results()?keys as aggregationKey>
      <h2>Aggregation: ${aggregationKey}</h2>

      <table>
      <#assign results = aggregations.results()[aggregationKey]/>
        <tr>
          <th colspan="3">Configuration</th>
          <#assign entry = (results?api.entrySet()?first)! />
          <#list 0..(testReport.maxIterations -1) as iteration>

            <#if entry?has_content && entry.getValue()?size gt iteration>
              <#assign testResult = entry.getValue()[iteration]/>
              <#assign iterationName = (testResult.getIteration().test.iterationsName)!/>
              <#if iterationName?has_content && testResult?has_content>
                <#assign iterationValue = (iterationName + "=" + testResult.getIteration().getValue() )/>
              <#else>
                <#assign iterationValue = ("Iteration " + iteration)/>
              </#if>
            <#else>
              <#assign iterationValue = ("Iteration " + iteration)/>
            </#if>
            <th>${iterationValue}</th>

          </#list>
        </tr>

        <#list results?keys as report>

          <#assign hiddenCounter++>

          <#if results?api.get(report)?size == 0>
            <#assign nodeCount = 0 />
          <#else>
            <#assign nodeCount = results?api.get(report)?first.workerResults?size />
          </#if>

          <tr>
            <th rowspan= ${nodeCount+1} onClick="switch_class_by_class('h_${hiddenCounter}','expanded','collapsed')" class="onClick">
              <img class="h_${hiddenCounter} expanded" src="ic_arrow_drop_down_black_24dp.png">
              <img class="h_${hiddenCounter} collapsed" src="ic_arrow_drop_up_black_24dp.png">
            </th>
            <th>${report.getConfiguration().name}</th>
            <th>${report.getCluster()}</th>

            <#assign dataCount = 0>

            <#list results?api.get(report) as result>
              <#assign rowClass = testReport.rowClass(result.suspicious) />
              <td class="${rowClass}">
                ${result.aggregatedValue}
              </td>
              <#assign dataCount = dataCount + 1 >
            </#list>

            <#-- Fill remaining cells because CSS -->
            <#if dataCount!=(testReport.maxIterations)>
              <#list dataCount..(testReport.maxIterations - 1)  as colNum>
                <td/>
              </#list>
            </#if>

          </tr>
          <#if testReport.configuration.generateNodeStats>
            <#list 0 .. (nodeCount - 1) as node>
              <tr class="h_${hiddenCounter} collapsed">
                <th/>
                <th> node${node}</th>

                <#assign dataCount = 0>

                <#list results?api.get(report) as result>
                  <#assign workerResult = (result.workerResults?api.get(node))! />
                  <#if workerResult?? && workerResult.value??>
                    <#assign rowClass = testReport.rowClass(result.suspicious) />
                    <td class="${rowClass}">
                      ${workerResult.value}
                    </td>
                  <#else >
                    <td/>
                  </#if>

                  <#assign dataCount = dataCount + 1>
                </#list>

                <#-- Fill remaining cells because CSS -->
                <#if dataCount!=(testReport.maxIterations)>
                  <#list dataCount..(testReport.maxIterations - 1)  as colNum>
                    <td/>
                  </#list>
                </#if>
              </tr>
            </#list>
          </#if>
        </#list>
      </table>
    </#list>
  </#list>
  <#list testReport.getOperationGroups() as operation>
    <h2>Operation: ${operation}</h2>

    <#-- place graphs -->
    <#if (testReport.getMaxClusters() > 1 && testReport.separateClusterCharts())>
      <#list testReport.getClusterSizes() as clusterSize>
        <#if (clusterSize > 0)>
          <#assign suffix = "_" + clusterSize />
        <#else>
          <#assign suffix = "" />
        </#if>
      <@graphs operation=operation suffix=suffix/>
      </#list>
    <#else>
      <#assign suffix = "" />
      <@graphs operation=operation suffix=suffix/>
    </#if>
    <br>

    <#assign i = 0 />
    <#list  testReport.getTestAggregations() as aggregations>
      <table>
      <#assign operationData = testReport.getOperationData(operation, aggregations.byReports())>
      <#assign numberOfColumns = testReport.numberOfColumns(operationData.getPresentedStatistics()) />

        <col/>
        <col/>
        <col/>
        <col/>

        <col/>
        <col/>
        <col/>
        <col/>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.OPERATION_THROUGHPUT) >
          <col/>
          <col class="tPut_with_errors collapsed"/>
        </#if>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.DATA_THROUGHPUT) >
          <col id="data throughput">
        </#if>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.PERCENTILES) >
          <#list testReport.configuration.percentiles as percentile>
            <col id="RTM at ${percentile} %">
          </#list>
        </#if>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.HISTOGRAM) >
          <col id="histograms">
        </#if>

        <tr>
          <th colspan="4"> Configuration ${testReport.getSingleTestName(i)}</th>
          <th>requests</th>
          <th>errors</th>
          <th>latency mean</th>
          <th>latency std.dev</th>
          <th>latency max</th>

          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.OPERATION_THROUGHPUT) >
            <th>throughput</th>
            <th>throughput w/ errors</th>
          </#if>
          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.DATA_THROUGHPUT) >
            <th colspan="4">data throughput</th>
          </#if>

          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.PERCENTILES) >
            <#list testReport.configuration.percentiles as percentile>
              <th>RTM at ${percentile} %</th>
            </#list>
          </#if>

          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.HISTOGRAM) >
            <th>histograms</th>
          </#if>
        </tr>

        <#assign reportAggregationMap = aggregations.byReports() />
        <#list reportAggregationMap?keys as report>

          <#assign hiddenCounter++>
          <#assign aggregs = reportAggregationMap?api.get(report) />
          <#assign nodeCount = report.getCluster().getSize() />
          <#assign threadCount = 0/>

          <#if testReport.configuration.generateThreadStats>
            <#list 0..nodeCount-1 as node>
              <#assign threadCount = threadCount + testReport.getMaxThreads(aggregs, node)/>
            </#list>
          </#if>

          <#assign rowspan = aggregations.getMaxIterations() />

          <#if testReport.configuration.generateNodeStats>
            <#assign rowspan = rowspan + aggregations.getMaxIterations()*nodeCount />
          </#if>

          <#if testReport.configuration.generateThreadStats>
            <#assign rowspan = rowspan + aggregations.getMaxIterations()*threadCount/>
          </#if>

          <tr>
            <th rowspan= ${rowspan} onClick="switch_class_by_class('h_${hiddenCounter}','expanded','collapsed')" class="onClick">
              <img class="h_${hiddenCounter} expanded" src="ic_arrow_drop_down_black_24dp.png">
              <img class="h_${hiddenCounter} collapsed" src="ic_arrow_drop_up_black_24dp.png">
            </th>
            <th rowspan= ${rowspan} >${report.getConfiguration().name}</th>
            <th rowspan= ${rowspan} >${report.getCluster()}</th>

            <#-- list all possible itteration ids -->
            <#list 0..(aggregations.getMaxIterations()-1) as iteration>
              <#assign aggregation = "" >

              <#-- fine if there is iteration matching the id -->
              <#list aggregs as agg>
                <#if agg.iteration.id==iteration>
                  <#assign aggregation = agg >
                </#if>
              </#list>

              <th>Iteration ${iteration}</th>

              <#-- write iteration totals -->
              <#if aggregation?? && aggregation != "">
                <@writeRepresentations statistics=aggregation.totalStats report=report aggregation=aggregation
                 node=-1 operation=operation/>
              <#else>
                <#-- Fill cells because CSS -->
                <#list 1..numberOfColumns as colNum>
                  <td/>
                </#list>
              </#if>

              <#-- write node totals -->
              <#if testReport.configuration.generateNodeStats>
                <#list 0..nodeCount-1 as node>
                  <tr class="h_${hiddenCounter} collapsed">
                  <th>Node ${node}</th>
                  <#if aggregation?? && aggregation != "">
                    <#assign statistics = testReport.getStatistics(aggregation, node)! />
                    <@writeRepresentations statistics=statistics report=report aggregation=aggregation
                                           node=node operation=operation/>
                  <#else>
                    <#-- Fill cells because CSS -->
                    <#list 1..numberOfColumns as colNum>
                      <td/>
                    </#list>
                  </#if>

                  <#-- write thread totals -->
                  <#if testReport.configuration.generateThreadStats>
                    <#assign maxThreads = testReport.getMaxThreads(aggregs, node) />
                    <#list 0..(maxThreads -1) as thread>
                      <tr class="h_${hiddenCounter} collapsed">
                        <th>thread ${node}_${thread}</th>
                        <#if aggregation?? && aggregation != "">
                          <#assign threadStats = (testReport.getThreadStatistics(aggregation, node, thread))! />
                          <@writeRepresentations statistics=threadStats report=report aggregation=aggregation
                                                 node=thread operation=operation/>
                        <#else>
                          <#-- Fill cells because CSS -->
                          <#list 1..numberOfColumns as colNum>
                            <td/>
                          </#list>
                        </#if>
                      </tr>
                    </#list>
                  </#if>
                </#list>
              </#if>
            </#list> <!-- iteration -->
          </tr>
        </#list> <!-- report -->
      </table>
    </#list> <!-- aggregations -->
  </#list> <!-- operation -->

  <#list testReport.getOperations() as operation>
    <h2>Operation: ${operation}</h2>

    <#-- place graphs -->
    <#if (testReport.getMaxClusters() > 1 && testReport.separateClusterCharts())>
      <#list testReport.getClusterSizes() as clusterSize>
        <#if (clusterSize > 0)>
          <#assign suffix = "_" + clusterSize />
        <#else>
          <#assign suffix = "" />
        </#if>
        <@graphs operation=operation suffix=suffix/>
      </#list>
    <#else>
      <#assign suffix = "" />
      <@graphs operation=operation suffix=suffix/>
    </#if>
    <br>

    <#assign i = 0 />
    <#list  testReport.getTestAggregations() as aggregations>
      <table>
      <#assign operationData = testReport.getOperationData(operation, aggregations.byReports())>
      <#assign numberOfColumns = testReport.numberOfColumns(operationData.getPresentedStatistics()) />

        <col/>
        <col/>
        <col/>
        <col/>

        <col/>
        <col/>
        <col/>
        <col/>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.OPERATION_THROUGHPUT) >
          <col/>
          <col class="tPut_with_errors collapsed"/>
        </#if>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.DATA_THROUGHPUT) >
          <col id="data throughput">
        </#if>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.PERCENTILES) >
          <#list testReport.configuration.percentiles as percentile>
            <col id="RTM at ${percentile} %">
          </#list>
        </#if>

        <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.HISTOGRAM) >
          <col id="histograms">
        </#if>

        <tr>
          <th colspan="4"> Configuration ${testReport.getSingleTestName(i)}</th>
          <th>requests</th>
          <th>errors</th>
          <th>latency mean</th>
          <th>latency std.dev</th>
          <th>latency max</th>

          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.OPERATION_THROUGHPUT) >
            <th>throughput</th>
            <th>throughput w/ errors</th>
          </#if>
          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.DATA_THROUGHPUT) >
            <th colspan="4">data throughput</th>
          </#if>

          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.PERCENTILES) >
            <#list testReport.configuration.percentiles as percentile>
              <th>RTM at ${percentile} %</th>
            </#list>
          </#if>

          <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.HISTOGRAM) >
            <th>histograms</th>
          </#if>
        </tr>

        <#assign reportAggregationMap = aggregations.byReports() />
        <#list reportAggregationMap?keys as report>
          <#assign hiddenCounter++>
          <#assign aggregs = reportAggregationMap?api.get(report) />
          <#assign nodeCount = report.getCluster().getSize() />
          <#assign threadCount = 0/>

          <#if testReport.configuration.generateThreadStats>
            <#list 0..nodeCount-1 as node>
              <#assign threadCount = threadCount + testReport.getMaxThreads(aggregs, node)/>
            </#list>
          </#if>

          <#assign rowspan = aggregations.getMaxIterations() />

          <#if testReport.configuration.generateNodeStats>
            <#assign rowspan = rowspan + aggregations.getMaxIterations()*nodeCount />
          </#if>

          <#if testReport.configuration.generateThreadStats>
            <#assign rowspan = rowspan + aggregations.getMaxIterations()*threadCount/>
          </#if>

          <tr>
            <th rowspan= ${rowspan} onClick="switch_class_by_class('h_${hiddenCounter}','expanded','collapsed')" class="onClick">
              <img class="h_${hiddenCounter} expanded" src="ic_arrow_drop_down_black_24dp.png">
              <img class="h_${hiddenCounter} collapsed" src="ic_arrow_drop_up_black_24dp.png">
            </th>
            <th rowspan= ${rowspan} >${report.getConfiguration().name}</th>
            <th rowspan= ${rowspan} >${report.getCluster()}</th>

            <#-- list all possible itteration ids -->
            <#list 0..(aggregations.getMaxIterations()-1) as iteration>

              <#if iteration != 0>
                </tr><tr>
              </#if>

              <#assign aggregation = "" >

              <#-- fine if there is iteration matching the id -->
              <#list aggregs as agg>
                <#if agg.iteration.id==iteration>
                  <#assign aggregation = agg >
                </#if>
              </#list>

              <th>Iteration ${iteration}</th>

              <#-- write iteration totals -->
              <#if aggregation?? && aggregation != "">
                <@writeRepresentations statistics=aggregation.totalStats report=report aggregation=aggregation
                                       node=-1 operation=operation/>
              <#else>
                <#-- Fill cells because CSS -->
                <#list 1..numberOfColumns as colNum>
                  <td/>
                </#list>
              </#if>


              <#-- write node totals -->
              <#if testReport.configuration.generateNodeStats>
                <#list 0..nodeCount-1 as node>
                  </tr><tr class="h_${hiddenCounter} collapsed">
                    <th>Node ${node}</th>
                    <#if aggregation?? && aggregation != "">
                      <#assign statistics = testReport.getStatistics(aggregation, node)! />
                      <@writeRepresentations statistics=statistics report=report aggregation=aggregation
                                             node=node operation=operation/>
                    <#else>
                      <#-- Fill cells because CSS -->
                      <#list 1..numberOfColumns as colNum>
                        <td/>
                      </#list>
                    </#if>

                    <#-- write thread totals -->
                    <#if testReport.configuration.generateThreadStats>
                      <#assign maxThreads = testReport.getMaxThreads(aggregs, node) />
                      <#list 0..(maxThreads -1) as thread>
                        </tr><tr class="h_${hiddenCounter} collapsed">
                          <th>thread ${node}_${thread}</th>
                            <#if aggregation?? && aggregation != "">
                              <#assign threadStats = (testReport.getThreadStatistics(aggregation, node, thread))! />
                              <@writeRepresentations statistics=threadStats report=report aggregation=aggregation
                                                     node=thread operation=operation/>
                            <#else>
                              <#-- Fill cells because CSS -->
                              <#list 1..numberOfColumns as colNum>
                                <td/>
                              </#list>
                            </#if>
                      </#list>
                    </#if> <!-- generate thread stats -->
                </#list> <!-- node -->
              </#if> <!-- generate node stats -->
            </#list> <!-- iteration -->
          </tr>
        </#list> <!-- report -->
      </table>
    </#list> <!-- aggregations -->
  </#list><!-- operation -->
</body>
</html>

<#macro graphs operation suffix>
  <table class="graphTable">
  <#list testReport.getGeneratedCharts(operation) as chart>
    <#local img = testReport.generateImageName(operation, suffix, chart.name + ".png")/>
    <#if chart?counter%2==1>
      <tr>
    </#if>
    <th>
      <br/>
      ${chart.title}<br/>
      <img src="${img}" alt="${operation}">
    </th>
    <#if chart?counter%2==0>
      </tr>
    </#if>
  </#list>
  </table>
</#macro>

<#macro writeRepresentations statistics report aggregation node operation>
  <#if !statistics?has_content>
    <#return>
  </#if>

  <#if statistics?has_content>
    <#local period = testReport.period(statistics)!0 />
  </#if>

  <#local defaultOutcome = statistics.getRepresentation(operation, testReport.defaultOutcomeClass())! />
  <#local meanAndDev = statistics.getRepresentation(operation, testReport.meanAndDevClass())! />
  <#local rowClass = testReport.rowClass(aggregation.anySuspect(operation)) />

  <#if rowClass=="highlight">
    <#local tooltip = "Node(s) significantly deviate from average result">
  <#else>
    <#local tooltip = "">
  </#if>

  <#if defaultOutcome?? && defaultOutcome?has_content>
    <td class="${rowClass} firstCellStyle" title="${tooltip}">
      ${defaultOutcome.requests}
    </td>
    <td class="${rowClass} rowStyle errorData" title="${tooltip}">
      ${defaultOutcome.errors}
    </td>
  <#else >
    <td class="${rowClass} firstCellStyle" title="${tooltip}"/>
    <td class="${rowClass} rowStyle" title="${tooltip}"/>
  </#if>

  <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.MEAN_AND_DEV)>
    <#if meanAndDev?has_content>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatTime(meanAndDev.mean)}
      </td>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatTime(meanAndDev.dev)}
      </td>
    <#else >
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
    </#if>
  </#if>

  <#if defaultOutcome?? && defaultOutcome?has_content>
    <td class="${rowClass} rowStyle" title="${tooltip}">
    ${testReport.formatTime(defaultOutcome.responseTimeMax)}
    </td>
  <#else >
    <td class="${rowClass} rowStyle" title="${tooltip}"/>
  </#if>

  <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.OPERATION_THROUGHPUT)>
    <#local operationThroughput = statistics.getRepresentation(operation, testReport.operationThroughputClass(), period)! />

    <#if operationThroughput?has_content>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatOperationThroughput(operationThroughput.net)}
      </td>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatOperationThroughput(operationThroughput.gross)}
      </td>
    <#else >
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
    </#if>
  </#if>

  <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.DATA_THROUGHPUT)>
    <#local dataThroughput = statistics.getRepresentation(operation, testReport.dataThroughputClass())! />
    <#if dataThroughput?has_content>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatDataThroughput(dataThroughput.minThroughput)} - min
      </td>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatDataThroughput(dataThroughput.maxThroughput)} - max
      </td>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatDataThroughput(dataThroughput.meanThroughput)} - mean
      </td>
      <td class="${rowClass} rowStyle" title="${tooltip}">
        ${testReport.formatDataThroughput(dataThroughput.deviation)} - std. dev
      </td>
    <#else >
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
      <td class="${rowClass} rowStyle" title="${tooltip}"/>
    </#if>
  </#if>

  <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.PERCENTILES)>
    <#list testReport.configuration.percentiles as percentile >
      <#local p = (statistics.getRepresentation(operation, testReport.percentileClass(), percentile?double))! />

      <#if p?has_content>
        <td class="${rowClass} rowStyle" title="${tooltip}">
          ${testReport.formatTime(p.responseTimeMax)}
        </td>
      <#else >
        <td class="${rowClass} rowStyle" title="${tooltip}"/>
      </#if>
    </#list>
  </#if>

  <!-- TODO: currently the charts for each configuration are generated multiple times;
             it would be nicer to have them only once, but that would require another loop
             through all clusters/iterations/nodes/threads. On the other hand the chart
             is created when opened and destroyed when closed, so it doesn't waste
             all the resources in runtime. -->
  <#if operationData.getPresentedStatistics()?seq_contains(StatisticType.HISTOGRAM)>
    <td class="${rowClass} rowStyle" title="${tooltip}">
      ${testReport.incElementCounter()}
      <div id="gh${testReport.getElementCounter()}" class="glasspanel" style="display: none">
        <a href="javascript: void(0);" class="popup_close" onclick="parentElement.style.display='none'; chartInPanel = chartInPanel.destroy();">Close X</a>
        <@histogram_chart operation=operation cluster=report.getCluster() iteration=aggregation.iteration.id node=node />
      </div>
      <div id="gp${testReport.getElementCounter()}" class="glasspanel" style="display: none">
        <a href="javascript: void(0);" class="popup_close" onclick="parentElement.style.display='none'; chartInPanel = chartInPanel.destroy();">Close X</a>
        <@percentiles_chart operation=operation cluster=report.getCluster() iteration=aggregation.iteration.id node=node/>
      </div>

      <a href="javascript: void(0);" onClick="javascript: chartInPanel = ch${testReport.getElementCounter()}(); show_panel('gh${testReport.getElementCounter()}', chartInPanel.destroy);">histogram</a> <br>
      <a href="javascript: void(0);" onClick="javascript: chartInPanel = cp${testReport.getElementCounter()}(); show_panel('gp${testReport.getElementCounter()}', chartInPanel.destroy);">percentiles</a>
    </td>
  </#if>
</#macro>

<#macro histogram_chart operation cluster iteration node>
  <#local chart = testReport.getHistogramChart(operation, cluster, iteration, node)>
  <div id="h${testReport.getElementCounter()}" class="popup_block"></div>
  <script type="text/javascript">
     function ch${testReport.getElementCounter()}() {
       return c3.generate({
         bindto: "#h${testReport.getElementCounter()}",
         size: {
           width: ${testReport.getConfiguration().getHistogramWidth()},
           height: ${testReport.getConfiguration().getHistogramHeight()}
         },
         padding: {
           right: 35, top: 20
         },
         data: {
           type: 'step',
           names: {
             <#list 0..chart.size() - 1 as line>
               line${line}: '${chart.name(line)}',
             </#list>
           },
           x: 'x',
           columns: [
               [ 'x', ${chart.times()}],
             <#list 0..chart.size() - 1 as line>
               [ 'line${line}', ${chart.percents(line)}],
             </#list>
           ],
         },
         axis: {
           x: {
             tick: {
               format: format_exp_ns,
               values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
             }
           },
           y: {
             tick: {
               format: function(value) { return (value * 100).toPrecision(3) + "%"},
               values: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1]
             }
           }
         },
         tooltip: {
           format: {
             title: function(value) {
               var quotient = ${chart.quotient()};
               return format_exp_ns(value - quotient) + " - " + format_exp_ns(value + quotient);
             }
           }
         }
       });
     }
   </script>
</#macro>

<#macro percentiles_chart operation cluster iteration node>
  <#local chart = testReport.getPercentilesChart(operation, cluster, iteration, node)>
  <div id="p${testReport.getElementCounter()}" class="popup_block"></div>
  <script type="text/javascript">
    function cp${testReport.getElementCounter()}() {
      return c3.generate({
        bindto: "#p${testReport.getElementCounter()}",
        size: {
          width: ${testReport.getConfiguration().getHistogramWidth()},
          height: ${testReport.getConfiguration().getHistogramHeight()}
        },
        padding: {
          right: 35, top: 20
        },
        data: {
          names: {
            <#list 0..chart.size() - 1 as line>
              line${2 * line}: '${chart.name(line)} (max)',
              line${2 * line + 1}: '${chart.name(line)} (avg)',
            </#list>
          },
          xs: {
            <#list 0..chart.size() - 1 as line>
              line${2 * line}: 'x${2 * line}',
              line${2 * line + 1}: 'x${2 * line + 1}',
            </#list>
          },
          columns: [
            <#list 0..chart.size() - 1 as line>
              [ 'x${2 * line}',     ${chart.percentiles(line)}],
              [ 'x${2 * line + 1}', ${chart.percentiles(line)}],
            </#list>
            <#list 0..chart.size() - 1 as line>
              [ 'line${2 * line}',     ${chart.max(line)}],
              [ 'line${2 * line + 1}', ${chart.avg(line)}],
            </#list>
          ],
        },
        color: {
          pattern: series_colors_dup()
        },
        axis: {
          x: {
            tick: {
              format: format_percentile,
              values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            }
          },
          y: {
            tick: {
              format: format_exp_ns,
              values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
            }
          }
        },
        point: {
          show: false
        },
        zoom: {
          enabled: true
        }
      });
    }
  </script>
</#macro>