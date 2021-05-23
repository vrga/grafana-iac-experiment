local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local statPanel = grafana.statPanel;
local prometheus = grafana.prometheus;
local template = grafana.template;
local gaugePanel = grafana.gaugePanel;
local graphPanel = grafana.graphPanel;

local quickGraph(
            title,
            targets,
            decimals=2,
            min=null,
            max=null,
            format=null,
            alignRight=false,
            bars=false,
            sort=1,
            hideEmpty=true,
            hideZero=true,
            repeat=null,
            nullPointMode='connected'
) = graphPanel.new(
        title,
        datasource='${datasource}',
        interval='$inter',
        decimals=decimals,
        min=min,
        max=max,
        format=format,
        legend_show=true,
        legend_values=true,
        legend_min=true,
        legend_max=true,
        legend_avg=true,
        legend_alignAsTable=true,
        legend_current=true,
        legend_rightSide=alignRight,
        bars=bars,
        sort=sort,
        legend_hideEmpty=hideEmpty,
        legend_hideZero=hideZero,
        repeat=repeat,
        nullPointMode=nullPointMode,
    ).addTargets(targets);

local panelTarget(
    title,
    query,
    instant=false,
    interval='$inter'
) = {
    legendFormat:   title,
    expr:           query,
    instant:        instant,
    interval:       interval,
};

local quickElem(
    title,
    query,
    type,
    instant=false,
    decimals=2,
    unit='none',
    min=null,
    max=null,
    thresholds=[]
) = if type == 'gauge' then
        gaugePanel.new(
            title,
            datasource='${datasource}',
            thresholdsMode='absolute',
            decimals=decimals,
            min=0,
            max=100,
            reducerFunction='lastNotNull',
            unit=unit,
        ).addTarget(
            prometheus.target(
              query,
              instant=instant,
            )
        ).addThresholds(thresholds)
    else if type == 'stat' then
        statPanel.new(
              title,
              datasource='${datasource}',
              decimals=decimals,
              unit=unit,
              min=null,
              max=null,
            ).addTarget(
              prometheus.target(
                query,
                instant=instant,
              )
            )
        ;


dashboard.new(
  'Prometheus telegraf single system dash',
  schemaVersion=27,
  tags=['prometheus', 'telegraf'],
  uid='jvsvpxrMz',
  editable=true,
)
.addTemplate(
  grafana.template.datasource(
    'datasource',
    'prometheus',
    'Prometheus',
    hide='label',
    refresh='time',
  )
)
.addTemplate(
  template.interval(
    'inter',
    'auto,10s,30s,1m,2m,5m,10m,30m,1h',
    'auto',
    label='Sampling',
    auto_count=100,
    auto_min='30s',
  )
)
.addTemplate(
  template.new(
    'server',
    '$datasource',
    'label_values(system_uptime, host)',
    label='Server',
    refresh='time',
  )
)
.addTemplate(
  template.new(
    'mountpoint',
    '$datasource',
    'label_values(disk_total{host="$server"},path)',
    label='Mountpoint',
    refresh='time',
    includeAll=true,
    multi=true,
    sort=1,
  )
)
.addTemplate(
  template.new(
    'cpu',
    '$datasource',
    'label_values(cpu_usage_system{host="$server"},cpu)',
    label='CPU',
    refresh='time',
    regex='/cpu[0-9]/',
    includeAll=true,
    multi=true,
    sort=3,
  )
)
.addTemplate(
  template.new(
    'disk',
    '$datasource',
    'label_values(diskio_reads{host="$server"},name)',
    label='Disk',
    refresh='time',
    includeAll=true,
    multi=true,
    sort=1,
    regex='[a-z]d[\\D]$|nvme[\\d]n[\\d]$',
  )
)
.addTemplate(
  template.new(
    'netif',
    '$datasource',
    'label_values(net_packets_recv{host="$server"},interface)',
    label='Network interface',
    refresh='time',
    includeAll=true,
    multi=true,
    sort=1,
  )
)
.addPanel(row.new('Quick overview'),{'h': 1, 'w':24, 'x': 0, 'y': 0})
.addPanel(
    quickElem(
        title='uptime',
        query='system_uptime{host="$server"}',
        type='stat',
        decimals=1,
        unit='s',
        instant=true,
    ),
    {'h':4,'w':4, 'x': 0, 'y': 1}
).addPanel(
    quickElem(
        title='LA medium',
        query='system_load5{host="$server"}',
        type='stat',
        decimals=2,
        instant=true,
    ),
    {'h':4,'w':2, 'x': 4, 'y': 1}
).addPanel(
    quickElem(
        title='Zombies',
        query='processes_zombies{host="$server"}',
        type='stat',
        decimals=0,
        thresholds=[
             { color: 'rgba(50, 172, 45, 0.97)',  value: null },
             { color: 'rgba(237, 129, 40, 0.89)', value: 1 },
             { color: 'rgba(245, 54, 54, 0.9)',   value: 5},
         ],
     ),
    {'h':4,'w':2, 'x': 6, 'y': 1}
).addPanel(
    quickElem(
        title='Processes',
        query='processes_total{host="$server"}',
        type='stat',
        decimals=0,
    ),
    {'h':4,'w':2, 'x': 8, 'y': 1}
).addPanel(
    quickElem(
        title='Threads',
        query='processes_total_threads{host="$server"}',
        type='stat',
        decimals=0,
    ),
     {'h':4,'w':2, 'x': 10, 'y': 1}
).addPanel(
    quickElem(
        title='CPU usage',
        query='cpu_usage_idle{host="$server",cpu="cpu-total"}*-1+100',
        type='gauge',
        decimals=2,
        unit='percent',
        thresholds=[
          { color: 'rgba(50, 172, 45, 0.97)',  value: null },
          { color: 'rgba(237, 129, 40, 0.89)', value: 70 },
          { color: 'rgba(245, 54, 54, 0.9)',   value: 80 },
        ],
    ),
     {'h':4,'w':2, 'x': 12, 'y': 1}
).addPanel(
    quickElem(
        title='RAM usage',
        query='mem_used_percent{host="$server"}',
        type='gauge',
        decimals=2,
        unit='percent',
        thresholds=[
          { color: 'rgba(50, 172, 45, 0.97)',  value: null },
          { color: 'rgba(237, 129, 40, 0.89)', value: 70 },
          { color: 'rgba(245, 54, 54, 0.9)',   value: 80 },
        ],
    ),
    {'h':4,'w':2, 'x': 14, 'y': 1}
).addPanel(
    quickElem(
        title='SWAP usage',
        query='swap_used_percent{host="$server"}',
        type='gauge',
        decimals=2,
        unit='percent',
        thresholds=[
            { color: 'rgba(50, 172, 45, 0.97)',  value: null },
            { color: 'rgba(237, 129, 40, 0.89)', value: 70 },
            { color: 'rgba(245, 54, 54, 0.9)',   value: 80 },
          ]
    ),
 {'h':4,'w':2, 'x': 16, 'y': 1}
).addPanel(
    quickElem(
        title='RootFS used',
        query='disk_used_percent{host="$server",path="/"}',
        type='gauge',
        decimals=2,
        unit='percent',
        thresholds=[
            { color: 'rgba(50, 172, 45, 0.97)',  value: null },
            { color: 'rgba(237, 129, 40, 0.89)', value: 70 },
            { color: 'rgba(245, 54, 54, 0.9)',   value: 80 },
          ]
    ),
  {'h':4,'w':2, 'x': 18, 'y': 1}
 ).addPanel(
     quickElem(
         title='IOWait',
         query='cpu_usage_iowait{host="$server", cpu="cpu-total"}',
         type='stat',
         decimals=2,
         unit='percent',
         min=0,
         max=100,
         thresholds=[
                { color: 'green',  value: null },
                { color: 'rgba(237, 129, 40, 0.89)', value: 60 },
                { color: 'dark-red',   value: 80 },
           ]
     ),
    {'h':4,'w':4, 'x': 20, 'y': 1}
)
.addPanel(row.new('CPU'),{'h': 1, 'w':24, 'x': 0, 'y': 5})
.addPanel(
     quickGraph(
        'CPU usage',
        min=0,
        max=100,
        format='percent',
        alignRight=true,
        targets=[
            panelTarget('user', 'cpu_usage_user{host="$server", cpu="cpu-total"}'),
            panelTarget('system', 'cpu_usage_system{host="$server", cpu="cpu-total"}'),
            panelTarget('softirq', 'cpu_usage_softirq{host="$server", cpu="cpu-total"}'),
            panelTarget('steal', 'cpu_usage_steal{host="$server", cpu="cpu-total"}'),
            panelTarget('nice', 'cpu_usage_nice{host="$server", cpu="cpu-total"}'),
            panelTarget('irq', 'cpu_usage_irq{host="$server", cpu="cpu-total"}'),
            panelTarget('iowait', 'cpu_usage_iowait{host="$server", cpu="cpu-total"}'),
            panelTarget('guest', 'cpu_usage_guest{host="$server", cpu="cpu-total"}'),
            panelTarget('guest_nice', 'cpu_usage_guest_nice{host="$server", cpu="cpu-total"}'),
        ]
    ),
    {'h':9, 'w':24, 'x': 0, 'y': 6}
).addPanel(quickGraph(
        'Load average',
        min=0,
        format='short',
        targets=[
            panelTarget('short', 'system_load1{host="$server"}'),
            panelTarget('medium', 'system_load5{host="$server"}'),
            panelTarget('long', 'system_load15{host="$server"}'),
        ]
     ),
    {'h':10, 'w':12, 'x': 0, 'y': 14}
).addPanel(quickGraph(
    'Processes',
    targets=[
        panelTarget('running', 'processes_running{host="$server"}'),
        panelTarget('blocked', 'processes_blocked{host="$server"}'),
        panelTarget('sleeping', 'processes_sleeping{host="$server"}'),
        panelTarget('stopped', 'processes_stopped{host="$server"}'),
        panelTarget('zombies', 'processes_zombies{host="$server"}'),
        panelTarget('paging', 'processes_paging{host="$server"}'),
        panelTarget('unknown', 'processes_unknown{host="$server"}'),
    ],
    decimals=0
    ),
    {'h':10, 'w':12, 'x': 12, 'y': 26}
)
.addPanel(row.new('Temps'),{'h': 1, 'w':24, 'x': 0, 'y': 38})
.addPanel(quickGraph(
        'Temperatures',
        format='celsius',
        min=20,
        max=100,
        decimals=null,
        targets=[
            panelTarget('{{chip}}:{{feature}}', 'sensors_temp_input{host="$server"}'),
            panelTarget('{{name}}-{{pstate}}', 'nvidia_smi_temperature_gpu{host="$server"}'),
        ]
    ),
    {'h':8, 'w':12, 'x': 0, 'y': 38}
)
.addPanel(quickGraph(
         'Disk temperatures',
         format='celsius',
         min=20,
         max=100,
         decimals=null,
         targets=[
             panelTarget('{{model}} - {{device}}', 'hddtemp_temperature{host="$server"}'),
         ]
     ),
     {'h':8, 'w':12, 'x': 12, 'y': 38}
 )
.addPanel(row.new('Memory'),{'h': 1, 'w':24, 'x': 0, 'y': 46})
.addPanel(quickGraph(
        'Memory usage',
        format='bytes',
        min=0,
        max=null,
        decimals=null,
        alignRight=true,
        targets=[
            panelTarget('total', 'mem_total{host="$server"}'),
            panelTarget('used', 'mem_used{host="$server"}'),
            panelTarget('cached', 'mem_cached{host="$server"}'),
            panelTarget('free', 'mem_free{host="$server"}'),
            panelTarget('buffered', 'mem_buffered{host="$server"}'),
        ]
    ),
    {'h':12, 'w':24, 'x': 0, 'y': 46}
)
.addPanel(row.new('Kernel'),{'h': 1, 'w':24, 'x': 0, 'y': 58})
.addPanel(quickGraph(
        'Context switches',
        format='ops',
        min=0,
        max=null,
        decimals=null,
        targets=[
            panelTarget('context switches', 'rate(kernel_context_switches{host="$server"}[$inter] >= 10)'),
        ]
    ),
    {'h':8, 'w':8, 'x': 0, 'y': 58}
).addPanel(quickGraph(
         'Forks',
         format='ops',
         min=0,
         max=null,
         decimals=null,
         targets=[
             panelTarget('forks', 'rate(kernel_processes_forked{host="$server"}[$inter] >= 10)'),
         ]
     ),
     {'h':8, 'w':8, 'x': 8, 'y': 58}
).addPanel(quickGraph(
          'File descriptors',
          format='short',
          min=0,
          max=null,
          decimals=null,
          targets=[
              panelTarget('max', 'linux_sysctl_fs_file-max{host="$server"}'),
              panelTarget('opened', 'linux_sysctl_fs_file-nr{host="$server"}'),
          ]
      ),
      {'h':8, 'w':8, 'x': 16, 'y': 58}
)
.addPanel(row.new('Interrupts'),{'h': 1, 'w':24, 'x': 0, 'y': 66})
.addPanel(quickGraph(
          'Interrupts',
          format='ops',
          min=0,
          max=null,
          decimals=null,
          targets=[
              panelTarget('{{irq}}', 'rate(interrupts_total{host="$server"} >= 10)'),
          ]
      ),
      {'h':12, 'w':24, 'x': 16, 'y': 66}
)
.addPanel(row.new('Per-cpu usage'),{'h': 1, 'w':24, 'x': 0, 'y': 72})
.addPanel(quickGraph(
          'CPU usage for $cpu',
          format='percent',
          min=0,
          max=100,
          decimals=null,
          repeat="cpu",
          targets=[
              panelTarget('user', 'cpu_usage_user{host="$server", cpu="$cpu"}'),
              panelTarget('system', 'cpu_usage_system{host="$server", cpu="$cpu"}'),
              panelTarget('softirq', 'cpu_usage_softirq{host="$server", cpu="$cpu"}'),
              panelTarget('steal', 'cpu_usage_steal{host="$server", cpu="$cpu"}'),
              panelTarget('nice', 'cpu_usage_nice{host="$server", cpu="$cpu"}'),
              panelTarget('irq', 'cpu_usage_irq{host="$server", cpu="$cpu"}'),
              panelTarget('iowait', 'cpu_usage_iowait{host="$server", cpu="$cpu"}'),
              panelTarget('guest', 'cpu_usage_guest{host="$server", cpu="$cpu"}'),
              panelTarget('guest_nice', 'cpu_usage_nice{host="$server", cpu="$cpu"}'),
          ]
      ),
      {'h':8, 'w':6, 'x': 0, 'y': 72}
)
.addPanel(row.new('Conntrack'),{'h': 1, 'w':24, 'x': 0, 'y': 80})
.addPanel(quickGraph(
          'Netfilter conntrack usage',
          format='short',
          min=0,
          decimals=null,
          targets=[
              panelTarget('current', 'conntrack_ip_conntrack_count{host="$server"}'),
              panelTarget('maximum', 'conntrack_ip_conntrack_max{host="$server"}'),
          ]
      ),
      {'h':8, 'w':24, 'x': 0, 'y': 80}
)
.addPanel(row.new('Network stack (TCP)'),{'h': 1, 'w':24, 'x': 0, 'y': 88})
.addPanel(quickGraph(
          'TCP connections',
          format='short',
          min=0,
          decimals=null,
          alignRight=true,
          sort=2,
          targets=[
              panelTarget('CLOSED', 'netstat_tcp_close{host="$server"}'),
              panelTarget('CLOSE_WAIT', 'netstat_tcp_close_wait{host="$server"}'),
              panelTarget('CLOSING', 'netstat_tcp_closing{host="$server"}'),
              panelTarget('ESTABLISHED', 'netstat_tcp_established{host="$server"}'),
              panelTarget('FIN_WAIT1', 'netstat_tcp_fin_wait_1{host="$server"}'),
              panelTarget('FIN_WAIT2', 'netstat_tcp_fin_wait_2{host="$server"}'),
              panelTarget('LAST_ACK', 'netstat_tcp_last_ack{host="$server"}'),
              panelTarget('SYN_RECV', 'netstat_tcp_syn_recv{host="$server"}'),
              panelTarget('SYN_SENT', 'netstat_tcp_syn_sent{host="$server"}'),
              panelTarget('TIME_WAIT', 'netstat_tcp_time_wait{host="$server"}'),
          ]
      ),
      {'h':8, 'w':24, 'x': 0, 'y': 88}
).addPanel(quickGraph(
           'TCP handshake issues',
           format='short',
           min=0,
           decimals=null,
           alignRight=true,
           sort=0,
           targets=[
               panelTarget('estabresets', 'rate(net_tcp_estabresets{host="$server"}[$inter])'),
               panelTarget('outrsts', 'rate(net_tcp_outrsts{host="$server"}[$inter])'),
               panelTarget('activeopens', 'rate(net_tcp_activeopens{host="$server"}[$inter])'),
               panelTarget('passiveopens', 'rate(net_tcp_passiveopens{host="$server"}[$inter])'),
           ]
       ),
       {'h':8, 'w':24, 'x': 0, 'y': 96}
).addPanel(quickGraph(
            'UDP datagrams',
            format='short',
            min=0,
            decimals=null,
            alignRight=true,
            sort=0,
            targets=[
                panelTarget('in datagrams',  'rate(net_udp_indatagrams{host="$server"}[$inter])'),
                panelTarget('out datagrams', 'rate(net_udp_outdatagrams{host="$server"}[$inter])'),
            ]
        ),
        {'h':8, 'w':24, 'x': 0, 'y': 104}
)
.addPanel(row.new('Network interface stats for $netif', repeat="netif"),{'h': 1, 'w':24, 'x': 0, 'y': 112})
.addPanel(quickGraph(
            'Network Usage',
            format='bps',
            decimals=null,
            sort=0,
            targets=[
                panelTarget('$netif: in',  'rate(net_bytes_recv{host="$server",interface="$netif"}[$inter]) * 8'),
                panelTarget('$netif: out', 'rate(net_bytes_sent{host="$server",interface="$netif"}[$inter])* 8 * -1'),
            ]
        ),
        {'h':8, 'w':12, 'x': 0, 'y': 112}
).addPanel(quickGraph(
             'Network Packets',
             format='pps',
             decimals=null,
             sort=0,
             targets=[
                 panelTarget('$netif: in',  'rate(net_packets_recv{host="$server",interface="$netif"}[$inter])'),
                 panelTarget('$netif: out', 'rate(net_packets_sent{host="$server",interface="$netif"}[$inter]) * -1'),
             ]
         ),
         {'h':8, 'w':12, 'x': 12, 'y': 112}
).addPanel(quickGraph(
              'Network drops',
              format='pps',
              decimals=null,
              sort=0,
              targets=[
                  panelTarget('$netif: in',  'rate(net_drop_in{host="$server",interface="$netif"}[$inter])'),
                  panelTarget('$netif: out', 'rate(net_drop_out{host="$server",interface="$netif"}[$inter]) * -1'),
              ]
          ),
          {'h':8, 'w':12, 'x': 0, 'y': 120}
).addPanel(quickGraph(
               'Network drops',
               format='short',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('$netif: in',  'rate(net_err_in{host="$server",interface="$netif"}[$inter])'),
                   panelTarget('$netif: out', 'rate(net_err_out{host="$server",interface="$netif"}[$inter]) * -1'),
               ]
           ),
           {'h':8, 'w':12, 'x': 12, 'y': 120}
)
.addPanel(row.new('Swap'),{'h': 1, 'w':24, 'x': 0, 'y': 128})
.addPanel(quickGraph(
               'Swap I/O bytes',
               format='bytes',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('in',  'rate(swap_in{host="$server"}[$inter])'),
                   panelTarget('out', 'rate(swap_out{host="$server"}[$inter]) * -1'),
               ]
           ),
           {'h':8, 'w':12, 'x': 0, 'y': 128}
)
.addPanel(quickGraph(
               'Swap usage',
               format='bytes',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('used', 'swap_used{host="$server"}'),
                   panelTarget('total', 'swap_total{host="$server"}'),
               ]
           ),
           {'h':8, 'w':12, 'x': 12, 'y': 128}
)
.addPanel(row.new('Disk IOPS for /dev/$disk', repeat="disk"),{'h': 1, 'w':24, 'x': 0, 'y': 136})
.addPanel(quickGraph(
               'Disk I/O requests for /dev/$disk',
               format='iops',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('$disk: read',  'rate(diskio_reads{host="$server",name="$disk"}[$inter])'),
                   panelTarget('$disk: write', 'rate(diskio_writes{host="$server",name="$disk"}[$inter]) * -1'),
               ]
           ),
           {'h':8, 'w':8, 'x': 0, 'y': 136}
)
.addPanel(quickGraph(
               'Disk I/O bytes for /dev/$disk',
               format='bytes',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('$disk: read',  'rate(diskio_read_bytes{host="$server",name="$disk"}[$inter])'),
                   panelTarget('$disk: write', 'rate(diskio_write_bytes{host="$server",name="$disk"}[$inter]) * -1'),
               ]
           ),
           {'h':8, 'w':8, 'x': 8, 'y': 136}
)
.addPanel(quickGraph(
               'Disk IOPS for /dev/$disk',
               format='ms',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('$disk: read',  'rate(diskio_read_time{host="$server",name="$disk"}[$inter])'),
                   panelTarget('$disk: write', 'rate(diskio_write_time{host="$server",name="$disk"}[$inter]) * -1'),
               ]
           ),
           {'h':8, 'w':8, 'x': 16, 'y': 136}
)
.addPanel(row.new('Disk space usage for $mountpoint', repeat="mountpoint"),{'h': 1, 'w':24, 'x': 0, 'y': 144})
.addPanel(quickGraph(
               'Disk usage for $mountpoint',
               format='bytes',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('$mountpoint: used',  'disk_used{host="$server",path="$mountpoint"}'),
                   panelTarget('$mountpoint: total', 'disk_total{host="$server",path="$mountpoint"}'),
               ]
           ),
           {'h':8, 'w':12, 'x': 0, 'y': 144}
)
.addPanel(quickGraph(
               'Disk inodes for $mountpoint',
               format='bytes',
               decimals=null,
               sort=0,
               targets=[
                   panelTarget('$mountpoint: used',  'disk_inodes_used{host="$server",path="$mountpoint"}'),
                   panelTarget('$mountpoint: total', 'disk_inodes_total{host="$server",path="$mountpoint"}'),
               ]
           ),
           {'h':8, 'w':12, 'x': 12, 'y': 144}
)