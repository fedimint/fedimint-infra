# Grafana dashboard: utilization of all runners combined and per host.
# Rendered to JSON by ./server.nix.
{ datasourceUid }:
let
  datasource = {
    type = "prometheus";
    uid = datasourceUid;
  };

  # Whole disks and real NICs only: LVM (dm-*) would double count disk IO,
  # and container/bot veths would double count network traffic.
  disk = ''device=~"nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+"'';
  nic = ''device=~"en.*|eth.*"'';
  rate = metric: "rate(${metric}[$__rate_interval])";

  cpuBusy = rate ''node_cpu_seconds_total{mode!="idle"}'';
  cpuAll = rate "node_cpu_seconds_total";
  memUsed = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes";
  diskBytes = "${rate "node_disk_read_bytes_total{${disk}}"} + ${rate "node_disk_written_bytes_total{${disk}}"}";
  netBytes = "${rate "node_network_receive_bytes_total{${nic}}"} + ${rate "node_network_transmit_bytes_total{${nic}}"}";

  target = expr: legendFormat: { inherit datasource expr legendFormat; };
  withRefIds =
    targets:
    builtins.genList (
      i: builtins.elemAt targets i // { refId = builtins.elemAt [ "A" "B" "C" "D" ] i; }
    ) (builtins.length targets);
  perHost = expr: target expr "{{instance}}";

  gridPos = x: y: w: h: {
    inherit
      x
      y
      w
      h
      ;
  };

  # Averaged over the selected time range, not just the latest value.
  stat =
    {
      title,
      expr,
      unit,
      x,
    }:
    {
      type = "stat";
      inherit title datasource;
      gridPos = gridPos x 0 4 4;
      targets = withRefIds [ (target expr "all") ];
      options = {
        reduceOptions.calcs = [ "mean" ];
        colorMode = "none";
        graphMode = "area";
      };
      fieldConfig.defaults = {
        inherit unit;
        decimals = 1;
      };
    };

  timeseries =
    {
      title,
      targets,
      unit,
      x,
      y,
      stacked ? false,
      max ? null,
      # Series drawn as an unstacked dashed line, e.g. a capacity limit.
      limitSeries ? null,
    }:
    {
      type = "timeseries";
      inherit title datasource;
      targets = withRefIds targets;
      gridPos = gridPos x y 12 8;
      options = {
        legend = {
          displayMode = "table";
          placement = "right";
          calcs = [
            "mean"
            "max"
          ];
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
      fieldConfig = {
        defaults = {
          inherit unit;
          custom = {
            fillOpacity = if stacked then 30 else 0;
            stacking.mode = if stacked then "normal" else "none";
          };
        }
        // (if max == null then { } else { inherit max; });
        overrides =
          if limitSeries == null then
            [ ]
          else
            [
              {
                matcher = {
                  id = "byName";
                  options = limitSeries;
                };
                properties = [
                  {
                    id = "custom.stacking";
                    value.mode = "none";
                  }
                  {
                    id = "custom.fillOpacity";
                    value = 0;
                  }
                  {
                    id = "custom.lineStyle";
                    value = {
                      fill = "dash";
                      dash = [
                        10
                        10
                      ];
                    };
                  }
                  {
                    id = "color";
                    value = {
                      mode = "fixed";
                      fixedColor = "text";
                    };
                  }
                ];
              }
            ];
      };
    };
in
{
  uid = "runners-overview";
  title = "Runners overview";
  tags = [ "runners" ];
  editable = true;
  refresh = "1m";
  schemaVersion = 39;
  time = {
    from = "now-24h";
    to = "now";
  };
  panels = [
    (stat {
      title = "CPU busy (all hosts)";
      expr = "sum(${cpuBusy}) / sum(${cpuAll})";
      unit = "percentunit";
      x = 0;
    })
    (stat {
      title = "Busy cores";
      expr = "sum(${cpuBusy})";
      unit = "short";
      x = 4;
    })
    (stat {
      title = "Total cores";
      expr = ''count(node_cpu_seconds_total{mode="idle"})'';
      unit = "short";
      x = 8;
    })
    (stat {
      title = "Memory used (all hosts)";
      expr = "sum(${memUsed}) / sum(node_memory_MemTotal_bytes)";
      unit = "percentunit";
      x = 12;
    })
    (stat {
      title = "Disk IO (all hosts)";
      expr = "sum(${diskBytes})";
      unit = "Bps";
      x = 16;
    })
    (stat {
      title = "Network (all hosts)";
      expr = "sum(${netBytes})";
      unit = "Bps";
      x = 20;
    })

    (timeseries {
      title = "CPU busy";
      unit = "percentunit";
      max = 1;
      x = 0;
      y = 4;
      targets = [
        (perHost "sum by (instance) (${cpuBusy}) / sum by (instance) (${cpuAll})")
        (target "sum(${cpuBusy}) / sum(${cpuAll})" "all hosts")
      ];
    })
    (timeseries {
      title = "Busy cores (stacked)";
      unit = "short";
      stacked = true;
      limitSeries = "total cores";
      x = 12;
      y = 4;
      targets = [
        (perHost "sum by (instance) (${cpuBusy})")
        (target ''count(node_cpu_seconds_total{mode="idle"})'' "total cores")
      ];
    })
    (timeseries {
      title = "Memory used (stacked)";
      unit = "bytes";
      stacked = true;
      limitSeries = "total memory";
      x = 0;
      y = 12;
      targets = [
        (perHost "sum by (instance) (${memUsed})")
        (target "sum(node_memory_MemTotal_bytes)" "total memory")
      ];
    })
    (timeseries {
      title = "Root filesystem used";
      unit = "percentunit";
      max = 1;
      x = 12;
      y = 12;
      targets = [
        (perHost ''1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}'')
      ];
    })
    (timeseries {
      title = "Disk IO, read + write (stacked)";
      unit = "Bps";
      stacked = true;
      x = 0;
      y = 20;
      targets = [ (perHost "sum by (instance) (${diskBytes})") ];
    })
    (timeseries {
      title = "Disk busy (busiest disk)";
      unit = "percentunit";
      max = 1;
      x = 12;
      y = 20;
      targets = [ (perHost "max by (instance) (${rate "node_disk_io_time_seconds_total{${disk}}"})") ];
    })
    (timeseries {
      title = "Network, in + out (stacked)";
      unit = "Bps";
      stacked = true;
      x = 0;
      y = 28;
      targets = [ (perHost "sum by (instance) (${netBytes})") ];
    })
    (timeseries {
      title = "Saturation: share of time tasks waited for CPU / IO";
      unit = "percentunit";
      x = 12;
      y = 28;
      targets = [
        (target (rate "node_pressure_cpu_waiting_seconds_total") "cpu {{instance}}")
        (target (rate "node_pressure_io_waiting_seconds_total") "io {{instance}}")
      ];
    })
  ];
}
