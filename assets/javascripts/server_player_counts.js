/* Uses the application's bundled D3 v3. */
(function () {
  "use strict";
  var root = d3.select("#server-player-counts");
  if (root.empty()) return;

  var status = root.select(".chart-status");
  var names = {server: "Direct polling", plugin: "Plug-in"};
  var colors = {server: "#62c5ff", plugin: "#ffb454"};
  var width = 960, height = 440;
  var margin = {top: 20, right: 25, bottom: 65, left: 65};
  var plotWidth = width - margin.left - margin.right;
  var plotHeight = height - margin.top - margin.bottom;
  var formatTime = d3.time.format.utc("%Y-%m-%d %H:%M:%S UTC");
  var svg = root.select(".chart").append("svg")
    .attr("viewBox", "0 0 " + width + " " + height)
    .attr("role", "img").attr("aria-labelledby", "player-count-chart-title");
  svg.append("title").attr("id", "player-count-chart-title")
    .text("Raw player count observations over the last two weeks, by source");
  var plot = svg.append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
  var x = d3.time.scale.utc().range([0, plotWidth]);
  var y = d3.scale.linear().range([plotHeight, 0]);
  var xAxis = plot.append("g").attr("class", "axis")
    .attr("transform", "translate(0," + plotHeight + ")");
  var yAxis = plot.append("g").attr("class", "axis");
  plot.append("text").attr("class", "axis-label")
    .attr("x", plotWidth / 2).attr("y", plotHeight + 50)
    .attr("text-anchor", "middle").text("Observation time (UTC)");
  plot.append("text").attr("class", "axis-label")
    .attr("transform", "rotate(-90)").attr("x", -plotHeight / 2)
    .attr("y", -48).attr("text-anchor", "middle").text("Players");
  var combined = plot.append("path").attr("class", "combined-line");
  var points = plot.append("g");

  d3.json(root.attr("data-url"), function (error, payload) {
    if (error) {
      status.text("Unable to load observations. Please reload to try again.");
      return;
    }
    var observations = payload.observations.map(function (d) {
      return {time: new Date(d.time), count: d.count, source: d.source};
    });
    x.domain([new Date(payload.start), new Date(payload.end)]);
    // Keep the scale fixed while toggling sources so comparisons stay meaningful.
    y.domain([0, Math.max(1, d3.max(observations, function (d) { return d.count; }) || 0)]).nice();
    xAxis.call(d3.svg.axis().scale(x).orient("bottom").ticks(7)
      .tickFormat(d3.time.format.utc("%b %d")));
    yAxis.call(d3.svg.axis().scale(y).orient("left").ticks(6).tickFormat(d3.format("d")));

    function render() {
      var enabled = {};
      root.selectAll("input").each(function () { enabled[this.name] = this.checked; });
      var visible = observations.filter(function (d) { return enabled[d.source]; });
      var line = d3.svg.line()
        .x(function (d) { return x(d.time); })
        .y(function (d) { return y(d.count); });
      combined.datum(visible).attr("d", enabled.combined ? line : null);
      var markers = points.selectAll("path").data(visible);
      markers.exit().remove();
      markers.enter().append("path").append("title");
      markers.attr("class", function (d) { return "observation " + d.source; })
        .attr("transform", function (d) { return "translate(" + x(d.time) + "," + y(d.count) + ")"; })
        .attr("fill", function (d) { return colors[d.source]; })
        .attr("d", d3.svg.symbol().size(35).type(function (d) {
          return d.source === "server" ? "circle" : "triangle-up";
        }));
      markers.select("title").text(function (d) {
        return names[d.source] + ": " + d.count + " players — " + formatTime(d.time);
      });
      if (!observations.length) {
        status.text("No observations in the last two weeks.");
      } else if (!enabled.server && !enabled.plugin) {
        status.text("Select a source to display observations.");
      } else if (!visible.length) {
        status.text("No observations for the selected sources in the last two weeks.");
      } else {
        status.text(visible.length + " of " + observations.length + " observations shown. Hover over a marker for its source, time, and count.");
      }
    }
    root.selectAll("input").on("change", render);
    render();
  });
}());
