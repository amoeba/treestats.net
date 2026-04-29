// popchart_v2.js — Interactive player population chart
// Features: line/stacked area toggle, brush time scrubber, label algorithm selector

var popchart_v2 = function (selector) {
  var url = "/player_counts_all.json";
  function escapeHTML(str) {
    return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  // Unique ID for this chart instance (for clip paths, etc.)
  var instanceId = "popchart-" + Math.random().toString(36).slice(2, 9);

  //=== CONFIGURATION ===
  const width = 960;
  const focusHeight = 460;
  const contextHeight = 80;
  const gapHeight = 30;
  const totalHeight = focusHeight + gapHeight + contextHeight;
  const margin = { top: 30, right: 200, bottom: 30, left: 60 };
  const ctxMargin = {
    top: focusHeight + gapHeight,
    right: 200,
    bottom: 20,
    left: 60,
  };

  const colorScale = d3.scaleOrdinal(d3.schemeTableau10);
  const transitionDuration = 600;

  //=== STATE ===
  // Curve options
  const curveOptions = [
    { value: "monotoneX", text: "Monotone X", fn: d3.curveMonotoneX },
    { value: "linear", text: "Linear", fn: d3.curveLinear },
    { value: "stepAfter", text: "Step", fn: d3.curveStepAfter },
    { value: "basis", text: "Basis (smooth)", fn: d3.curveBasis },
    { value: "cardinal", text: "Cardinal", fn: d3.curveCardinal },
    { value: "catmullRom", text: "Catmull-Rom", fn: d3.curveCatmullRom },
    { value: "natural", text: "Natural", fn: d3.curveNatural },
  ];
  const curveMap = new Map(curveOptions.map((o) => [o.value, o.fn]));

  // Parse initial state from URL
  const urlParams = new URLSearchParams(window.location.search);

  let allData = [];
  let chartType = urlParams.get("type") || "line";
  let labelAlgorithm = urlParams.get("labels") || "force";
  let curveType = urlParams.get("curve") || "monotoneX";
  let activeServers = new Set();
  let focusXDomain = null; // set by brush
  let renderedData = []; // current chart data (aggregated, gap-filled)
  let renderedStacked = null; // stacked layout when in area mode

  // URL params for initial server selection (applied after data loads)
  const urlServers = urlParams.get("servers");
  const urlFrom = urlParams.get("from");
  const urlTo = urlParams.get("to");

  //=== DOM SETUP ===
  const container = d3.select(selector);

  // Loading indicator
  const loadingEl = container
    .append("div")
    .attr("class", "chart-loading")
    .text("Loading…");

  // SVG
  const svg = container
    .append("svg")
    .attr("viewBox", [0, 0, width, totalHeight])
    .attr("preserveAspectRatio", "xMidYMid meet")
    .style("display", "none");

  // Clip path for the focus area
  svg
    .append("defs")
    .append("clipPath")
    .attr("id", instanceId + "-clip")
    .append("rect")
    .attr("x", margin.left)
    .attr("y", margin.top)
    .attr("width", width - margin.left - margin.right)
    .attr("height", focusHeight - margin.top - margin.bottom);

  // Groups
  const focusGroup = svg.append("g").attr("class", "focus");
  const areaGroup = focusGroup
    .append("g")
    .attr("class", "areas")
    .attr("clip-path", "url(#" + instanceId + "-clip)");
  const lineGroup = focusGroup
    .append("g")
    .attr("class", "lines")
    .attr("clip-path", "url(#" + instanceId + "-clip)");
  const labelGroup = focusGroup.append("g").attr("class", "labels");
  const axisXGroup = focusGroup.append("g").attr("class", "x-axis");
  const axisYGroup = focusGroup.append("g").attr("class", "y-axis");
  const totalPopGroup = focusGroup.append("g").attr("class", "total-pop");
  const bucketIndicator = focusGroup.append("g").attr("class", "bucket-indicator");

  const contextGroup = svg.append("g").attr("class", "context");
  const ctxAreaGroup = contextGroup.append("g").attr("class", "ctx-lines");
  const ctxAxisXGroup = contextGroup.append("g").attr("class", "ctx-x-axis");
  const brushGroup = contextGroup.append("g").attr("class", "brush");

  // Hover elements
  const hoverLine = focusGroup
    .append("line")
    .attr("class", "hover-line")
    .attr("stroke", "rgba(255,255,255,0.3)")
    .attr("stroke-width", 1)
    .attr("y1", margin.top)
    .attr("y2", focusHeight - margin.bottom)
    .style("display", "none");

  const tooltip = container
    .append("div")
    .attr("class", "chart-tooltip")
    .style("display", "none");

  //=== SCALES ===
  const xScale = d3.scaleUtc();
  const yScale = d3.scaleLinear();
  const ctxXScale = d3.scaleUtc();
  const ctxYScale = d3.scaleLinear();

  //=== GENERATORS ===
  function getCurve() {
    return curveMap.get(curveType) || d3.curveMonotoneX;
  }

  const lineGen = d3
    .line()
    .defined((d) => d.count != null)
    .x((d) => xScale(d.date))
    .y((d) => yScale(d.count));

  const areaGen = d3
    .area()
    .defined((d) => d.data._defined)
    .x((d) => xScale(d.data.date));

  const ctxLineGen = d3
    .line()
    .defined((d) => d.count != null)
    .x((d) => ctxXScale(d.date))
    .y((d) => ctxYScale(d.count));

  //=== BRUSH ===
  const brush = d3
    .brushX()
    .extent([
      [ctxMargin.left, ctxMargin.top],
      [width - ctxMargin.right, totalHeight - ctxMargin.bottom],
    ])
    .on("brush end", brushed);

  function brushed(event) {
    if (!event.selection) return;
    const [x0, x1] = event.selection.map(ctxXScale.invert);
    focusXDomain = [x0, x1];
    render({ brushing: true });
    if (event.type === "end") updateURL();
  }

  //=== DATA LOADING ===
  function tidy(raw) {
    return raw.map((d) => ({
      date: d3.utcParse("%Y%m%d")(d.date),
      count: d.count,
      server: d.server,
    }));
  }

  function loadData() {
    d3.json(url)
      .then((raw) => {
        allData = tidy(raw);
        if (allData.length === 0) {
          loadingEl.text("No data available.");
          return;
        }
        loadingEl.style("display", "none");
        svg.style("display", null);

        // Initialize active servers
        const servers = [...new Set(allData.map((d) => d.server))].sort();
        colorScale.domain(servers);

        // Restore server selection from URL, or default to all
        if (urlServers) {
          const selected = new Set(urlServers.split(","));
          servers.forEach((s) => {
            if (selected.has(s)) activeServers.add(s);
          });
        } else {
          servers.forEach((s) => activeServers.add(s));
        }

        // Build server filter UI
        buildServerFilter(servers);

        // Restore date range from URL, or default to last 30 days
        const fullExtent = d3.extent(allData, (d) => d.date);
        if (urlFrom && urlTo) {
          const from = dateParse(urlFrom);
          const to = dateParse(urlTo);
          if (from && to) {
            focusXDomain = [
              d3.max([fullExtent[0], from]),
              d3.min([fullExtent[1], to]),
            ];
          }
        }
        if (!focusXDomain) {
          const thirtyDaysAgo = d3.utcDay.offset(fullExtent[1], -30);
          focusXDomain = [
            d3.max([fullExtent[0], thirtyDaysAgo]),
            fullExtent[1],
          ];
        }

        // Initial render
        renderContext();
        render({});

        // Set initial brush position
        const brushSel = [
          ctxXScale(focusXDomain[0]),
          ctxXScale(focusXDomain[1]),
        ];
        brushGroup.call(brush.move, brushSel);

        // Set up interactions
        setupHover();

        // Show through-date derived from actual data max (always UTC)
        const throughDate = d3.utcFormat("%b %d, %Y")(d3.max(allData, (d) => d.date));
        container
          .append("p")
          .attr("class", "through-date")
          .style("font-size", "11px")
          .style("color", "rgba(220, 220, 220, 0.5)")
          .style("margin", "2px 0 0 0")
          .text("Data through " + throughDate + " (UTC)");
      })
      .catch((err) => {
        console.error(err);
        loadingEl.text("Error loading data. " + (err.message || ""));
      });
  }

  //=== DATA PROCESSING ===
  function getFilteredData() {
    return allData.filter((d) => activeServers.has(d.server));
  }

  function getFocusData() {
    const filtered = getFilteredData();
    if (!focusXDomain) return filtered;
    return filtered.filter(
      (d) => d.date >= focusXDomain[0] && d.date <= focusXDomain[1]
    );
  }

  function pivotData(data, servers) {
    const byDate = d3.group(data, (d) => +d.date);
    const dates = [...byDate.keys()].sort((a, b) => a - b);

    return dates.map((dateMs) => {
      const row = { date: new Date(dateMs) };
      const entries = byDate.get(dateMs);
      // _defined is false if ALL servers have null counts at this date
      let anyDefined = false;
      servers.forEach((s) => {
        const entry = entries ? entries.find((e) => e.server === s) : null;
        if (entry && entry.count != null) {
          row[s] = entry.count;
          anyDefined = true;
        } else {
          row[s] = 0;
        }
      });
      row._defined = anyDefined;
      return row;
    });
  }

  // Choose a time bucket based on visible range span
  function chooseBucket(data) {
    const extent = d3.extent(data, (d) => d.date);
    const spanDays = (extent[1] - extent[0]) / (1000 * 60 * 60 * 24);

    if (spanDays <= 90) return "daily";
    if (spanDays <= 365) return "weekly";
    return "monthly";
  }

  // Aggregate data into weekly or monthly buckets using max per server per bucket
  function aggregateData(data, bucket) {
    if (bucket === "daily") return data;

    const bucketFn =
      bucket === "weekly"
        ? (d) => d3.utcMonday(d.date).getTime()
        : (d) => d3.utcMonth(d.date).getTime();

    // Group by (server, bucket) and take max count
    const grouped = d3.group(data, (d) => d.server);
    const result = [];

    grouped.forEach((values, server) => {
      const byBucket = d3.group(values, bucketFn);
      byBucket.forEach((entries, bucketKey) => {
        result.push({
          date: new Date(bucketKey),
          count: d3.max(entries, (e) => e.count),
          server: server,
        });
      });
    });

    return result.sort((a, b) => a.date - b.date);
  }

  // Insert null entries for missing time slots so lines break at gaps
  function fillGaps(data, bucket) {
    const interval =
      bucket === "monthly"
        ? d3.utcMonth
        : bucket === "weekly"
          ? d3.utcMonday
          : d3.utcDay;

    // Build the full set of expected time slots from the data's extent
    const extent = d3.extent(data, (d) => d.date);
    if (!extent[0]) return data;
    const allSlots = interval.range(extent[0], d3.utcDay.offset(extent[1], 1));
    const slotSet = new Set(allSlots.map((d) => +d));

    const servers = [...new Set(data.map((d) => d.server))];

    // Index existing data: server -> date_ms -> entry
    const index = new Map();
    data.forEach((d) => {
      const key = `${d.server}-${+d.date}`;
      index.set(key, d);
    });

    const result = [];
    servers.forEach((s) => {
      allSlots.forEach((date) => {
        const existing = index.get(`${s}-${+date}`);
        if (existing) {
          result.push(existing);
        } else {
          result.push({ date, count: null, server: s });
        }
      });
    });

    return result;
  }

  //=== RENDER ===
  function render({ brushing = false } = {}) {
    // Update curve on generators
    const curve = getCurve();
    lineGen.curve(curve);
    areaGen.curve(curve);

    const rawData = getFocusData();
    const bucket = chooseBucket(rawData);
    const data = fillGaps(aggregateData(rawData, bucket), bucket);
    renderedData = data;
    const servers = [...activeServers].sort();

    // Clear everything if no data
    if (data.length === 0 || servers.length === 0) {
      renderedData = [];
      lineGroup.selectAll("path").remove();
      areaGroup.selectAll("path").remove();
      labelGroup.selectAll("*").remove();
      totalPopGroup.selectAll("*").remove();
      return;
    }

    // Update focus scales
    xScale
      .domain(focusXDomain || d3.extent(data, (d) => d.date))
      .range([margin.left, width - margin.right]);

    // For stacked area, yMax is the sum; for lines, it's the max value
    let yMax;
    if (chartType === "area") {
      const pivoted = pivotData(data, servers);
      const byDate = pivoted.map((row) =>
        servers.reduce((sum, s) => sum + row[s], 0)
      );
      yMax = d3.max(byDate);
    } else {
      yMax = d3.max(data, (d) => d.count);
    }
    yScale
      .domain([0, yMax * 1.05])
      .range([focusHeight - margin.bottom, margin.top]);

    const t = brushing
      ? d3.transition().duration(50)
      : d3.transition().duration(transitionDuration);

    // Axes
    renderAxes(t);

    // Chart content — always clear the inactive type immediately
    if (chartType === "line") {
      renderLines(data, servers, t);
      renderedStacked = null;
      areaGroup.selectAll("path").interrupt().remove();
    } else {
      renderAreas(data, servers, t);
      lineGroup.selectAll("path").interrupt().remove();
    }

    // Labels
    renderLabels(data, servers);

    // Total population
    renderTotalPop(data, servers, bucket);

    // Bucket indicator
    renderBucketIndicator(bucket);
  }

  function renderAxes(t) {
    axisXGroup
      .attr("transform", `translate(0,${focusHeight - margin.bottom})`)
      .transition(t)
      .call(
        d3
          .axisBottom(xScale)
          .ticks(width / 120)
          .tickSizeOuter(0)
      );

    axisYGroup
      .attr("transform", `translate(${margin.left},0)`)
      .transition(t)
      .call(d3.axisLeft(yScale).ticks(focusHeight / 60));
  }

  //=== LINE CHART ===
  function renderLines(data, servers, t) {
    const grouped = d3.group(data, (d) => d.server);

    // Interrupt any running transitions so data rebinding works cleanly
    lineGroup.selectAll("path").interrupt();

    const paths = lineGroup.selectAll("path").data(
      servers.map((s) => ({ server: s, values: grouped.get(s) || [] })),
      (d) => d.server
    );

    paths.exit().remove();

    const entered = paths
      .enter()
      .append("path")
      .attr("fill", "none")
      .attr("stroke-width", 1.5)
      .attr("opacity", 0);

    entered
      .merge(paths)
      .attr("stroke", (d) => colorScale(d.server))
      .transition(t)
      .attr("opacity", 1)
      .attr("d", (d) => lineGen(d.values));
  }

  //=== STACKED AREA CHART ===
  function renderAreas(data, servers, t) {
    const pivoted = pivotData(data, servers);
    const stackGen = d3.stack().keys(servers).order(d3.stackOrderDescending);
    const layers = stackGen(pivoted);
    renderedStacked = { layers, pivoted, servers };

    areaGen.y0((d) => yScale(d[0])).y1((d) => yScale(d[1]));

    // Interrupt any running transitions so data rebinding works cleanly
    areaGroup.selectAll("path").interrupt();

    const paths = areaGroup.selectAll("path").data(layers, (d) => d.key);

    paths.exit().remove();

    const entered = paths
      .enter()
      .append("path")
      .attr("opacity", 0)
      .attr("stroke", "rgba(0,0,0,0.2)")
      .attr("stroke-width", 0.5);

    entered
      .merge(paths)
      .attr("fill", (d) => colorScale(d.key))
      .transition(t)
      .attr("opacity", 0.85)
      .attr("d", (d) => areaGen(d));
  }

  //=== CONTEXT (BRUSH) CHART ===
  function renderContext() {
    ctxLineGen.curve(getCurve());
    const data = getFilteredData();
    const servers = [...activeServers].sort();
    const grouped = d3.group(data, (d) => d.server);

    ctxXScale
      .domain(d3.extent(data, (d) => d.date))
      .range([ctxMargin.left, width - ctxMargin.right]);
    ctxYScale
      .domain([0, d3.max(data, (d) => d.count)])
      .range([totalHeight - ctxMargin.bottom, ctxMargin.top]);

    // Draw mini lines
    ctxAreaGroup.selectAll("path").remove();
    servers.forEach((s) => {
      const values = grouped.get(s) || [];
      ctxAreaGroup
        .append("path")
        .attr("fill", "none")
        .attr("stroke", colorScale(s))
        .attr("stroke-width", 0.8)
        .attr("opacity", 0.6)
        .attr("d", ctxLineGen(values));
    });

    // Context X axis
    ctxAxisXGroup
      .attr("transform", `translate(0,${totalHeight - ctxMargin.bottom})`)
      .call(
        d3
          .axisBottom(ctxXScale)
          .ticks(width / 120)
          .tickSizeOuter(0)
      );

    // Brush
    brushGroup.call(brush);

    // Style the brush
    brushGroup
      .selectAll(".selection")
      .attr("fill", "rgba(175, 122, 48, 0.3)")
      .attr("stroke", "#af7a30");
  }

  //=== LABELS ===
  function renderLabels(data, servers) {
    labelGroup.selectAll("*").remove();

    const grouped = d3.group(data, (d) => d.server);
    const labelData = servers
      .map((s) => {
        const values = grouped.get(s);
        if (!values || values.length === 0) return null;
        // Find last non-null data point
        let last = null;
        for (let i = values.length - 1; i >= 0; i--) {
          if (values[i].count != null) {
            last = values[i];
            break;
          }
        }
        if (!last) return null;
        return {
          server: s,
          date: last.date,
          count: last.count,
          x: xScale(last.date),
          y: yScale(last.count),
        };
      })
      .filter(Boolean);

    switch (labelAlgorithm) {
      case "end":
        labelAlgoEnd(labelData);
        break;
      case "force":
        labelAlgoForce(labelData);
        break;
      case "collapsed":
        labelAlgoCollapsed(labelData);
        break;
      case "column":
        labelAlgoColumn(labelData);
        break;
    }

    // Attach hover handlers to all labels
    setupLabelHover();
  }

  function setupLabelHover() {
    labelGroup
      .selectAll(".line-label")
      .attr("cursor", "pointer")
      .on("pointerenter", function (event, d) {
        const server = d && d.server
          ? d.server
          : d3.select(this).text().split(":")[0];

        // Highlight the matching series
        lineGroup
          .selectAll("path")
          .attr("opacity", (p) => (p.server === server ? 1 : 0.15));
        areaGroup
          .selectAll("path")
          .attr("opacity", (p) => (p.key === server ? 0.85 : 0.2));

        // Highlight matching label, fade others
        labelGroup
          .selectAll(".line-label")
          .attr("opacity", function () {
            const text = d3.select(this).text();
            return text.startsWith(server + ":") ? 1 : 0.2;
          });
        labelGroup
          .selectAll(".connector, .leader-line")
          .attr("opacity", function () {
            const datum = d3.select(this).datum();
            return datum && datum.server === server ? 0.8 : 0.1;
          });
      })
      .on("pointerleave", function () {
        // Restore all
        lineGroup.selectAll("path").attr("opacity", 1);
        areaGroup.selectAll("path").attr("opacity", 0.85);
        labelGroup.selectAll(".line-label").attr("opacity", 1);
        labelGroup.selectAll(".connector, .leader-line").attr("opacity", 0.5);
      });
  }

  // Algorithm 1: Labels at end of line
  function labelAlgoEnd(labelData) {
    labelGroup
      .selectAll("text")
      .data(labelData, (d) => d.server)
      .join("text")
      .attr("class", "line-label")
      .attr("x", (d) => d.x + 6)
      .attr("y", (d) => d.y)
      .attr("dy", "0.35em")
      .attr("font-size", 10)
      .attr("font-family", "sans-serif")
      .attr("fill", (d) => colorScale(d.server))
      .text((d) => `${d.server}: ${d.count}`);
  }

  // Algorithm 2: Force-directed label placement
  function labelAlgoForce(labelData) {
    const labelHeight = 13;
    const labelPad = 2;
    const rightEdge = width - margin.right + 6;
    const minY = margin.top;
    const maxY = focusHeight - margin.bottom;

    // Create simulation nodes — only move along Y
    const nodes = labelData.map((d) => ({
      ...d,
      targetY: d.y,
    }));

    // Sort by target Y so initial positions are reasonable
    nodes.sort((a, b) => a.targetY - b.targetY);

    // Custom rectangular collision that only pushes along Y
    function forceRectCollide() {
      const rowH = labelHeight + labelPad;
      return () => {
        for (let i = 0; i < nodes.length; i++) {
          for (let j = i + 1; j < nodes.length; j++) {
            const a = nodes[i];
            const b = nodes[j];
            const dy = b.y - a.y;
            if (Math.abs(dy) < rowH) {
              const push = (rowH - Math.abs(dy)) / 2;
              a.y -= push;
              b.y += push;
            }
          }
        }
      };
    }

    // Run force simulation
    const simulation = d3
      .forceSimulation(nodes)
      .force(
        "y",
        d3.forceY((d) => d.targetY).strength(0.3)
      )
      .force("rectCollide", forceRectCollide())
      .force(
        "clamp",
        () => {
          nodes.forEach((n) => {
            n.y = Math.max(minY, Math.min(maxY, n.y));
          });
        }
      )
      .stop();

    // Run synchronously
    for (let i = 0; i < 300; i++) simulation.tick();

    // Post-process: enforce original Y order (higher count = lower Y value)
    // Sort nodes by their original targetY and re-assign positions
    // so labels never appear out of data order
    const rowH = labelHeight + labelPad;
    const ordered = [...nodes].sort((a, b) => a.targetY - b.targetY);
    // Collect the resolved Y positions, also sorted
    const resolvedYs = ordered.map((n) => n.y).sort((a, b) => a - b);
    // Assign sorted positions back in order
    ordered.forEach((n, i) => {
      n.y = resolvedYs[i];
    });

    // One final pass to ensure no overlap after reordering
    for (let i = 1; i < ordered.length; i++) {
      if (ordered[i].y - ordered[i - 1].y < rowH) {
        ordered[i].y = ordered[i - 1].y + rowH;
      }
    }

    // Clamp again after reordering
    nodes.forEach((n) => {
      n.y = Math.max(minY, Math.min(maxY, n.y));
    });

    // Draw connector lines from data endpoint to label
    labelGroup
      .selectAll("line.connector")
      .data(nodes, (d) => d.server)
      .join("line")
      .attr("class", "connector")
      .attr("x1", (d) => d.x)
      .attr("y1", (d) => d.targetY)
      .attr("x2", rightEdge)
      .attr("y2", (d) => d.y)
      .attr("stroke", (d) => colorScale(d.server))
      .attr("stroke-width", 0.8)
      .attr("stroke-dasharray", "2,2")
      .attr("opacity", 0.5);

    // Draw labels
    labelGroup
      .selectAll("text")
      .data(nodes, (d) => d.server)
      .join("text")
      .attr("class", "line-label")
      .attr("x", rightEdge)
      .attr("y", (d) => d.y)
      .attr("dy", "0.35em")
      .attr("font-size", 10)
      .attr("font-family", "sans-serif")
      .attr("fill", (d) => colorScale(d.server))
      .text((d) => `${d.server}: ${d.count}`);
  }

  // Algorithm 3: Collapsed marks with tooltips
  function labelAlgoCollapsed(labelData) {
    if (labelData.length === 0) return;

    const labelHeight = 13;
    const overlapThreshold = labelHeight;

    // Sort by y position
    const sorted = [...labelData].sort((a, b) => a.y - b.y);

    // Group overlapping labels
    const groups = [];
    let currentGroup = [sorted[0]];

    for (let i = 1; i < sorted.length; i++) {
      const prev = currentGroup[currentGroup.length - 1];
      if (Math.abs(sorted[i].y - prev.y) < overlapThreshold) {
        currentGroup.push(sorted[i]);
      } else {
        groups.push(currentGroup);
        currentGroup = [sorted[i]];
      }
    }
    if (currentGroup.length > 0) groups.push(currentGroup);

    const rightEdge = width - margin.right + 6;

    groups.forEach((group) => {
      if (group.length === 1) {
        // Single label — show normally
        const d = group[0];
        labelGroup
          .append("text")
          .datum(d)
          .attr("class", "line-label")
          .attr("x", rightEdge)
          .attr("y", d.y)
          .attr("dy", "0.35em")
          .attr("font-size", 10)
          .attr("font-family", "sans-serif")
          .attr("fill", colorScale(d.server))
          .text(`${d.server}: ${d.count}`);
      } else {
        // Collapsed group — show circle marker
        const avgY =
          group.reduce((sum, d) => sum + d.y, 0) / group.length;
        const tooltipText = group
          .map((d) => `<strong style="color:${colorScale(d.server)}">${escapeHTML(d.server)}</strong>: ${d.count}`)
          .join("<br>");

        const circle = labelGroup
          .append("circle")
          .attr("class", "collapsed-mark")
          .attr("cx", rightEdge + 4)
          .attr("cy", avgY)
          .attr("r", 6)
          .attr("fill", "rgba(175, 122, 48, 0.8)")
          .attr("stroke", "#af7a30")
          .attr("stroke-width", 1)
          .attr("cursor", "pointer");

        // Count badge
        labelGroup
          .append("text")
          .attr("x", rightEdge + 4)
          .attr("y", avgY)
          .attr("dy", "0.35em")
          .attr("text-anchor", "middle")
          .attr("font-size", 8)
          .attr("font-family", "sans-serif")
          .attr("fill", "white")
          .attr("pointer-events", "none")
          .text(group.length);

        // Connector lines from marker to each line end
        group.forEach((d) => {
          labelGroup
            .append("line")
            .attr("class", "connector")
            .attr("x1", d.x)
            .attr("y1", d.y)
            .attr("x2", rightEdge + 4)
            .attr("y2", avgY)
            .attr("stroke", colorScale(d.server))
            .attr("stroke-width", 0.6)
            .attr("stroke-dasharray", "2,2")
            .attr("opacity", 0.4);
        });

        // Tippy tooltip
        if (typeof tippy !== "undefined") {
          tippy(circle.node(), {
            content: tooltipText,
            allowHTML: true,
            theme: "dark",
            placement: "right",
          });
        }
      }
    });
  }

  // Algorithm 4: Right column layout with leader lines
  function labelAlgoColumn(labelData) {
    const rightEdge = width - margin.right + 10;
    const labelHeight = 14;
    const availableHeight = focusHeight - margin.top - margin.bottom;

    // Sort by count descending
    const sorted = [...labelData].sort((a, b) => b.count - a.count);

    // Evenly space labels in the available height
    const spacing = Math.min(
      labelHeight,
      availableHeight / sorted.length
    );
    const totalLabelHeight = spacing * sorted.length;
    const startY =
      margin.top + (availableHeight - totalLabelHeight) / 2 + spacing / 2;

    sorted.forEach((d, i) => {
      const labelY = startY + i * spacing;

      // Curved leader line using a bezier
      const midX = (d.x + rightEdge) / 2 + 20;
      labelGroup
        .append("path")
        .datum(d)
        .attr("class", "leader-line")
        .attr(
          "d",
          `M${d.x},${d.y} C${midX},${d.y} ${midX},${labelY} ${rightEdge - 4},${labelY}`
        )
        .attr("fill", "none")
        .attr("stroke", colorScale(d.server))
        .attr("stroke-width", 0.8)
        .attr("opacity", 0.5);

      // Small dot at line endpoint
      labelGroup
        .append("circle")
        .datum(d)
        .attr("cx", d.x)
        .attr("cy", d.y)
        .attr("r", 2)
        .attr("fill", colorScale(d.server));

      // Label text
      labelGroup
        .append("text")
        .datum(d)
        .attr("class", "line-label")
        .attr("x", rightEdge)
        .attr("y", labelY)
        .attr("dy", "0.35em")
        .attr("font-size", 10)
        .attr("font-family", "sans-serif")
        .attr("fill", colorScale(d.server))
        .text(`${d.server}: ${d.count}`);
    });
  }

  //=== TOTAL POPULATION ===
  function renderTotalPop(data, servers, bucket) {
    totalPopGroup.selectAll("*").remove();
    if (servers.length <= 1) return;

    // Compute daily totals (sum all servers per date)
    const byDate = d3.rollup(
      data,
      (v) => d3.sum(v, (d) => d.count),
      (d) => +d.date
    );
    const dailyTotals = [...byDate.values()];

    if (dailyTotals.length === 0) return;

    // Date range
    const dates = [...byDate.keys()].sort((a, b) => a - b);
    const current = byDate.get(dates[dates.length - 1]);
    const min = d3.min(dailyTotals);
    const max = d3.max(dailyTotals);
    const mean = Math.round(d3.mean(dailyTotals));
    const median = Math.round(d3.median(dailyTotals));
    const dateFrom = d3.utcFormat("%b %d, %Y")(new Date(dates[0]));
    const dateTo = d3.utcFormat("%b %d, %Y")(new Date(dates[dates.length - 1]));

    const stats = [
      `Now: ${current}`,
      `Min: ${min}`,
      `Max: ${max}`,
      `Med: ${median}`,
      `Avg: ${mean}`,
      `(${dateFrom} – ${dateTo})`,
    ];

    totalPopGroup
      .append("text")
      .attr("class", "total_pop")
      .attr("x", margin.left + 10)
      .attr("y", margin.top + 16)
      .attr("font-size", 12)
      .attr("font-weight", "bold")
      .attr("fill", "gold")
      .text(stats.join("  ·  "));
  }

  //=== BUCKET INDICATOR ===
  function renderBucketIndicator(bucket) {
    bucketIndicator.selectAll("*").remove();

    const label =
      bucket === "daily" ? "Daily" : bucket === "weekly" ? "Weekly" : "Monthly";

    const g = bucketIndicator
      .append("g")
      .attr("transform", `translate(${width - margin.right - 6}, ${margin.top + 16})`);

    const text = g
      .append("text")
      .attr("text-anchor", "end")
      .attr("font-size", 11)
      .attr("font-family", "sans-serif")
      .attr("fill", "rgba(220, 220, 220, 0.7)")
      .text(label);

    // Add a background pill behind the text
    const bbox = text.node().getBBox();
    g.insert("rect", "text")
      .attr("x", bbox.x - 5)
      .attr("y", bbox.y - 2)
      .attr("width", bbox.width + 10)
      .attr("height", bbox.height + 4)
      .attr("rx", 3)
      .attr("fill", "rgba(175, 122, 48, 0.25)")
      .attr("stroke", "rgba(175, 122, 48, 0.5)")
      .attr("stroke-width", 0.5);
  }

  //=== HOVER INTERACTION ===
  function setupHover() {
    const overlay = focusGroup
      .append("rect")
      .attr("class", "hover-overlay")
      .attr("x", margin.left)
      .attr("y", margin.top)
      .attr("width", width - margin.left - margin.right)
      .attr("height", focusHeight - margin.top - margin.bottom)
      .attr("fill", "none")
      .attr("pointer-events", "all");

    overlay
      .on("pointerenter", () => {
        hoverLine.style("display", null);
        tooltip.style("display", null);
      })
      .on("pointermove", (event) => {
        const [mx, my] = d3.pointer(event);
        const hoveredDate = xScale.invert(mx);

        // Use the same data the chart was rendered with, excluding nulls
        const validData = renderedData.filter((d) => d.count != null);
        if (validData.length === 0) return;

        hoverLine.attr("x1", mx).attr("x2", mx);

        // Find nearest date
        const allDates = [
          ...new Set(validData.map((d) => +d.date)),
        ]
          .sort((a, b) => a - b)
          .map((d) => new Date(d));

        const bisect = d3.bisector((d) => d.getTime()).left;
        const idx = bisect(allDates, hoveredDate.getTime(), 1);
        const d0 = allDates[idx - 1];
        const d1 = allDates[idx];
        const nearestDate =
          !d0 ? d1 :
          !d1 ? d0 :
          hoveredDate - d0 > d1 - hoveredDate ? d1 : d0;

        if (!nearestDate) return;

        // Get non-null values at this date
        const valuesAtDate = validData
          .filter((d) => +d.date === +nearestDate)
          .sort((a, b) => b.count - a.count);

        if (valuesAtDate.length === 0) return;

        // Find closest server by y distance
        // In stacked area mode, use the stacked midpoint Y for hit testing
        let closest;
        if (chartType === "area" && renderedStacked) {
          const { layers, pivoted } = renderedStacked;
          const dateIdx = pivoted.findIndex((r) => +r.date === +nearestDate);
          if (dateIdx >= 0) {
            closest = d3.least(layers, (layer) => {
              const d = layer[dateIdx];
              const midY = yScale((d[0] + d[1]) / 2);
              return Math.abs(midY - my);
            });
            // Convert from layer to matching valuesAtDate entry
            closest = valuesAtDate.find((v) => v.server === closest.key) || valuesAtDate[0];
          } else {
            closest = d3.least(valuesAtDate, (d) =>
              Math.abs(yScale(d.count) - my)
            );
          }
        } else {
          closest = d3.least(valuesAtDate, (d) =>
            Math.abs(yScale(d.count) - my)
          );
        }

        if (!closest) return;

        // Highlight that server's line
        lineGroup
          .selectAll("path")
          .attr("opacity", (d) =>
            d.server === closest.server ? 1 : 0.15
          );

        areaGroup
          .selectAll("path")
          .attr("opacity", (d) =>
            d.key === closest.server ? 0.85 : 0.2
          );

        labelGroup
          .selectAll(".line-label")
          .attr("opacity", function () {
            const text = d3.select(this).text();
            return text.startsWith(closest.server + ":") ? 1 : 0.2;
          });

        // Tooltip content
        const dateStr = d3.utcFormat("%b %d, %Y")(nearestDate);
        const total = d3.sum(valuesAtDate, (v) => v.count);
        let html = `<div class="tt-date">${dateStr}</div>`;

        if (chartType === "area" && valuesAtDate.length > 1) {
          // Stacked mode: show hovered server first, then rest, then total
          const others = valuesAtDate.filter((v) => v.server !== closest.server);
          html += `<div class="tt-hovered" style="color:${colorScale(closest.server)}">▶ ${escapeHTML(closest.server)}: ${closest.count}</div>`;
          if (others.length > 0) {
            html += `<div class="tt-separator"></div>`;
            others.forEach((v) => {
              html += `<div class="tt-other" style="color:${colorScale(v.server)}">${escapeHTML(v.server)}: ${v.count}</div>`;
            });
          }
          html += `<div class="tt-total">Total: ${total}</div>`;
        } else {
          if (valuesAtDate.length > 1) {
            html += `<div class="tt-total">Total: ${total}</div>`;
          }
          valuesAtDate.forEach((v) => {
            const highlight = v.server === closest.server ? "font-weight:bold;" : "";
            html += `<div style="color:${colorScale(v.server)};${highlight}">${escapeHTML(v.server)}: ${v.count}</div>`;
          });
        }

        tooltip.html(html);

        // Position tooltip
        const svgNode = svg.node();
        const svgRect = svgNode.getBoundingClientRect();
        const scale = svgRect.width / width;
        // Position tooltip, clamping to viewport
        const ttNode = tooltip.node();
        const ttW = ttNode.offsetWidth;
        const ttH = ttNode.offsetHeight;
        let tooltipX = svgRect.left + mx * scale + 15;
        let tooltipY = svgRect.top + my * scale - 10;

        if (tooltipX + ttW > window.innerWidth - 8) {
          tooltipX = svgRect.left + mx * scale - ttW - 15;
        }
        if (tooltipY + ttH > window.innerHeight - 8) {
          tooltipY = window.innerHeight - ttH - 8;
        }
        if (tooltipY < 8) tooltipY = 8;

        tooltip.style("left", tooltipX + "px").style("top", tooltipY + "px");
      })
      .on("pointerleave", () => {
        hoverLine.style("display", "none");
        tooltip.style("display", "none");

        // Restore opacity
        lineGroup.selectAll("path").attr("opacity", 1);
        areaGroup.selectAll("path").attr("opacity", 0.85);
        labelGroup.selectAll(".line-label").attr("opacity", 1);
      });
  }

  //=== CONTROLS ===
  //=== URL STATE ===
  const dateFmt = d3.utcFormat("%Y%m%d");
  const dateParse = d3.utcParse("%Y%m%d");

  function updateURL() {
    const params = new URLSearchParams();
    params.set("type", chartType);
    params.set("labels", labelAlgorithm);
    params.set("curve", curveType);

    if (focusXDomain) {
      params.set("from", dateFmt(focusXDomain[0]));
      params.set("to", dateFmt(focusXDomain[1]));
    }

    if (activeServers.size > 0) {
      const allServers = [...new Set(allData.map((d) => d.server))].sort();
      // Only include servers param if not all servers are selected
      if (activeServers.size < allServers.length) {
        params.set("servers", [...activeServers].sort().join(","));
      }
    }

    const newURL =
      window.location.pathname + "?" + params.toString();
    window.history.replaceState(null, "", newURL);
  }

  function buildControls() {
    const controls = d3
      .select(selector)
      .insert("div", ":first-child")
      .attr("class", "chart-controls");

    // Chart type toggle
    const typeCtrl = controls.append("div").attr("class", "control-group");
    typeCtrl.append("span").attr("class", "control-label").text("Chart Type");
    const typeBtns = typeCtrl.append("div").attr("class", "toggle-buttons");

    typeBtns
      .append("button")
      .attr("class", "toggle-btn" + (chartType === "line" ? " active" : ""))
      .attr("data-type", "line")
      .text("Line")
      .on("click", function () {
        chartType = "line";
        typeBtns.selectAll(".toggle-btn").classed("active", false);
        d3.select(this).classed("active", true);
        updateURL();
        render({});
      });

    typeBtns
      .append("button")
      .attr("class", "toggle-btn" + (chartType === "area" ? " active" : ""))
      .attr("data-type", "area")
      .text("Stacked Area")
      .on("click", function () {
        chartType = "area";
        typeBtns.selectAll(".toggle-btn").classed("active", false);
        d3.select(this).classed("active", true);
        updateURL();
        render({});
      });

    // Label algorithm
    const labelCtrl = controls.append("div").attr("class", "control-group");
    labelCtrl
      .append("span")
      .attr("class", "control-label")
      .text("Label Placement");
    const labelSel = labelCtrl
      .append("select")
      .attr("class", "control-select")
      .on("change", function () {
        labelAlgorithm = this.value;
        updateURL();
        render({});
      });

    [
      { value: "end", text: "End of Line" },
      { value: "force", text: "Force-Directed (no overlap)" },
      { value: "collapsed", text: "Collapsed Marks (tooltip)" },
      { value: "column", text: "Right Column (leader lines)" },
    ].forEach((opt) => {
      labelSel
        .append("option")
        .attr("value", opt.value)
        .property("selected", opt.value === labelAlgorithm)
        .text(opt.text);
    });

    // Interpolation
    const curveCtrl = controls.append("div").attr("class", "control-group");
    curveCtrl
      .append("span")
      .attr("class", "control-label")
      .text("Interpolation");
    const curveSel = curveCtrl
      .append("select")
      .attr("class", "control-select")
      .on("change", function () {
        curveType = this.value;
        updateURL();
        renderContext();
        render({});
      });

    curveOptions.forEach((opt) => {
      curveSel
        .append("option")
        .attr("value", opt.value)
        .property("selected", opt.value === curveType)
        .text(opt.text);
    });
  }

  function buildServerFilter(servers) {
    // Server filter below chart
    const filterContainer = d3
      .select(selector)
      .append("div")
      .attr("class", "server-filter");

    filterContainer
      .append("span")
      .attr("class", "control-label")
      .text("Servers");

    // Quick filter buttons
    const quickBtns = filterContainer
      .append("div")
      .attr("class", "quick-filters");

    quickBtns
      .append("button")
      .attr("class", "filter-btn")
      .text("All")
      .on("click", () => {
        activeServers = new Set(servers);
        filterContainer.selectAll("input[type=checkbox]").property("checked", true);
        updateURL();
        renderContext();
        render({});
      });

    quickBtns
      .append("button")
      .attr("class", "filter-btn")
      .text("None")
      .on("click", () => {
        activeServers.clear();
        filterContainer.selectAll("input[type=checkbox]").property("checked", false);
        updateURL();
        renderContext();
        render({});
      });

    // Checkbox list
    const checkboxes = filterContainer
      .append("div")
      .attr("class", "server-checkboxes");

    servers.forEach((s) => {
      const lbl = checkboxes
        .append("label")
        .attr("class", "server-checkbox");

      lbl
        .append("input")
        .attr("type", "checkbox")
        .property("checked", activeServers.has(s))
        .on("change", function () {
          if (this.checked) {
            activeServers.add(s);
          } else {
            activeServers.delete(s);
          }
          updateURL();
          renderContext();
          render({});
        });

      lbl
        .append("span")
        .attr("class", "server-swatch")
        .style("background-color", colorScale(s));

      lbl.append("span").text(s);
    });
  }

  //=== INITIALIZE ===
  buildControls();
  loadData();
};
