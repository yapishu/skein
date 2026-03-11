/-  *skein
/+  dbug, verb, default-agent, server
|%
::  configuration
::
++  seen-ttl  ~h1
++  max-routes  100
++  max-relays  64
++  epoch-period  ~s30
++  discovery-period  ~m5
++  default-min-hops  0
++  cover-chance  3
::
::  internal types
::
+$  pending-forward
  $:  next=ship
      cell=relay-cell
  ==
::
+$  mix-state
  $:  batch=(list pending-forward)
      timer=(unit @da)
  ==
::
::  state-12: blind routing — no cleartext origin/target/route in cells
::  states 0-11 dropped (incompatible types); fresh start on upgrade
::
+$  state-12
  $:  %12
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-key=relay-key
  ==
::
::  state-13: adds channel-based peer discovery
::
+$  state-13
  $:  %13
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-key=relay-key
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
  ==
::
::  state-14: configurable min-hops
::
+$  state-14
  $:  %14
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-key=relay-key
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
  ==
::
+$  current-state  state-14
+$  card  card:agent:gall
::
::  path helpers
::
++  inbox-path
  |=  app=app-id
  ^-  path
  /app/[app]/inbox
::
++  relay-events-path
  ^-  path
  /relay/events
::
::  queue helpers
::
++  queue-for
  |=  [app=app-id queues=(map app-id (list envelope))]
  ^-  (list envelope)
  (~(gut by queues) app ~)
::
++  put-queue
  |=  [app=app-id env=envelope queues=(map app-id (list envelope))]
  ^-  (map app-id (list envelope))
  (~(put by queues) app [env (queue-for app queues)])
::
::  card builders
::
++  message-card
  |=  env=envelope
  ^-  card
  [%give %fact [(inbox-path app.target.env)]~ %skein-event !>([%message env])]
::
++  relay-card
  |=  ev=event
  ^-  card
  [%give %fact [relay-events-path]~ %skein-event !>(ev)]
::
++  send-cell-card
  |=  [who=ship cell=relay-cell]
  ^-  card
  =/  seg=@ta  (scot %uv cell-id.cell)
  [%pass /cell/[seg] %agent [who %skein] %poke %skein-cell !>(cell)]
::
++  pool-fact-card
  |=  pool=(list relay-descriptor)
  ^-  card
  [%give %fact [/relay/pool]~ %skein-relay-pool !>(pool)]
::
++  subscribe-relay-card
  |=  [our=ship rd=relay-descriptor]
  ^-  card
  =/  seg=@ta  (scot %p ship.rd)
  [%pass /relay/sub/[seg] %agent [ship.rd %skein] %watch /relay/pool]
::
++  channel-sub-card
  |=  [relay-ship=ship cid=channel-id]
  ^-  card
  =/  seg=@ta  (scot %p relay-ship)
  [%pass /channel/sub/[seg]/[cid] %agent [relay-ship %skein] %watch /channel/[cid]]
::
++  channel-unsub-card
  |=  [relay-ship=ship cid=channel-id]
  ^-  card
  =/  seg=@ta  (scot %p relay-ship)
  [%pass /channel/sub/[seg]/[cid] %agent [relay-ship %skein] %leave ~]
::
++  self-descriptor
  |=  [our=ship our-key=relay-key]
  ^-  relay-descriptor
  =/  rid=relay-id  (scot %p our)
  [rid our our-key 1 ~ ~]
::
++  known-ships
  |=  relays=(map relay-id relay-descriptor)
  ^-  (set ship)
  %-  ~(rep by relays)
  |=  [[rid=relay-id rd=relay-descriptor] out=(set ship)]
  (~(put in out) ship.rd)
::
++  merge-relays
  |=  [ours=ship pool=(list relay-descriptor) relays=(map relay-id relay-descriptor)]
  ^-  [(list relay-descriptor) (map relay-id relay-descriptor)]
  ::  returns [new-descriptors updated-map]
  ::  caps at max-relays, deduplicates by ship, skips self
  =/  ships=(set ship)  (known-ships relays)
  =/  new=(list relay-descriptor)  ~
  |-
  ?~  pool  [(flop new) relays]
  ?:  (gte ~(wyt by relays) max-relays)
    [(flop new) relays]
  ?:  =(ship.i.pool ours)
    $(pool t.pool)
  ?:  (~(has in ships) ship.i.pool)
    $(pool t.pool)
  =.  relays  (~(put by relays) relay.i.pool i.pool)
  =.  ships   (~(put in ships) ship.i.pool)
  =.  new  [i.pool new]
  $(pool t.pool)
::
++  discovery-sub-cards
  |=  [our=ship relays=(map relay-id relay-descriptor) wex=(map [wire ship term] [acked=? =path])]
  ^-  (list card)
  =/  rds=(list relay-descriptor)  (relays-list relays)
  %+  murn  rds
  |=  rd=relay-descriptor
  ?:  =(ship.rd our)  ~
  =/  sub-wire=wire  /relay/sub/(scot %p ship.rd)
  ?:  (~(has by wex) [sub-wire ship.rd %skein])  ~
  `(subscribe-relay-card our rd)
::
++  wait-card
  |=  [wire=path when=@da]
  ^-  card
  [%pass wire %arvo %b %wait when]
::
::  replay detection
::
++  seen-step
  |=  [cell=relay-cell seen=(map @uv @da)]
  ^-  ?
  (~(has by seen) cell-id.cell)
::
++  remember-step
  |=  [cell=relay-cell seen=(map @uv @da) now=@da]
  ^-  (map @uv @da)
  (~(put by seen) cell-id.cell now)
::
++  prune-seen
  |=  [seen=(map @uv @da) now=@da]
  ^-  (map @uv @da)
  =/  cutoff=@da  (sub now seen-ttl)
  %-  ~(rep by seen)
  |=  [[cid=@uv at=@da] out=(map @uv @da)]
  ?:  (lth at cutoff)
    out
  (~(put by out) cid at)
::
::  route helpers
::
++  route-tail
  |=  ships=(list ship)
  ^-  (unit ship)
  ?~  ships  ~
  |-  ?~(t.ships `i.ships $(ships t.ships))
::
++  route-ships
  |=  [target=endpoint opts=send-options]
  ^-  (list ship)
  =/  ships=(list ship)
    ?~  route.opts  ~
    (turn hops.u.route.opts |=(hop=route-hop ship.hop))
  ?~  last=(route-tail ships)
    ~[ship.target]
  ?:  =(ship.target u.last)
    ships
  (snoc ships ship.target)
::
++  cell-id-for
  |=  [id=@ud origin=endpoint target=endpoint sent-at=@da]
  ^-  @uv
  (sham [id origin target sent-at])
::
++  local-endpoint
  |=  [app=app-id our=ship]
  ^-  endpoint
  [our app]
::
++  relay-by-id
  |=  [relays=(map relay-id relay-descriptor) relay=relay-id]
  ^-  (unit relay-descriptor)
  (~(get by relays) relay)
::
++  normalize-hop
  |=  [hop=route-hop relays=(map relay-id relay-descriptor)]
  ^-  route-hop
  =/  descriptor=(unit relay-descriptor)  (relay-by-id relays relay.hop)
  ?~  descriptor  hop
  =/  delay=(unit @dr)
    ?~(delay.hop default-delay.u.descriptor delay.hop)
  [ship.hop relay.hop key.hop delay]
::
++  hydrate-route
  |=  [raw=route relays=(map relay-id relay-descriptor)]
  ^-  route
  [route-id.raw (turn hops.raw |=(hop=route-hop (normalize-hop hop relays)))]
::
++  relays-list
  |=  relays=(map relay-id relay-descriptor)
  ^-  (list relay-descriptor)
  (turn ~(tap by relays) |=([p=relay-id q=relay-descriptor] q))
::
++  live-relay
  |=  [descriptor=relay-descriptor now=@da]
  ^-  ?
  ?~  expiry.descriptor  %.y
  (lth now u.expiry.descriptor)
::
++  eligible-relays
  |=  [our=ship relays=(map relay-id relay-descriptor) target=ship now=@da]
  ^-  (list relay-descriptor)
  %+  murn  (relays-list relays)
  |=  d=relay-descriptor
  ?:  =(ship.d our)  ~
  ?:  =(ship.d target)  ~
  ?.  (live-relay d now)  ~
  `d
::
++  shuffle-relays
  |=  [eny=@ relays=(list relay-descriptor)]
  ^-  (list relay-descriptor)
  %+  sort  relays
  |=  [a=relay-descriptor b=relay-descriptor]
  (lth (mug (sham [eny relay.a])) (mug (sham [eny relay.b])))
::
++  unique-hops
  |=  [relays=(list relay-descriptor) count=@ud exclude=(set ship)]
  ^-  (list route-hop)
  ?:  =(count 0)  ~
  ?~  relays  ~
  ?:  (~(has in exclude) ship.i.relays)
    $(relays t.relays)
  =/  hop=route-hop
    [ship.i.relays relay.i.relays key.i.relays default-delay.i.relays]
  [hop $(count (dec count), relays t.relays, exclude (~(put in exclude) ship.i.relays))]
::
++  target-route-hop
  |=  [relays=(map relay-id relay-descriptor) target=ship now=@da]
  ^-  (unit route-hop)
  =/  descriptors=(list relay-descriptor)  (relays-list relays)
  |-  ^-  (unit route-hop)
  ?~  descriptors  ~
  ?.  ?&(=(ship.i.descriptors target) (live-relay i.descriptors now))
    $(descriptors t.descriptors)
  `[ship.i.descriptors relay.i.descriptors key.i.descriptors default-delay.i.descriptors]
::
++  select-route
  |=  [our=ship target=endpoint relays=(map relay-id relay-descriptor) now=@da eny=@ min-hops=@ud]
  ^-  (unit route)
  =/  candidates=(list relay-descriptor)
    (shuffle-relays eny (eligible-relays our relays ship.target now))
  =/  final-hop=(unit route-hop)  (target-route-hop relays ship.target now)
  =/  exclude=(set ship)
    ?~  final-hop  ~
    (sy ~[ship.target])
  =/  mids=(list route-hop)  (unique-hops candidates min-hops exclude)
  =/  hops=(list route-hop)
    ?~  final-hop  mids
    (snoc mids u.final-hop)
  ?~  hops  ~
  `[(sham [eny target now]) hops]
::
++  route-last-hop
  |=  hops=(list route-hop)
  ^-  (unit route-hop)
  ?~  hops  ~
  |-  ?~(t.hops `i.hops $(hops t.hops))
::
++  route-head
  |=  hops=(list route-hop)
  ^-  (unit route-hop)
  ?~  hops  ~
  `i.hops
::
++  trim-routes
  |=  routes=(list route-log)
  ^-  (list route-log)
  (scag max-routes routes)
::
::  crypto helpers
::
++  derive-key
  |=  [tag=@t base=relay-key cell-id=@uv]
  ^-  @ux
  (shaz (jam [tag base cell-id]))
::
++  box-atom
  |=  [key=relay-key data=@]
  ^-  @ux
  (en:crub:crypto key data)
::
++  open-atom
  |=  [key=relay-key box=@ux]
  ^-  (unit @ux)
  (de:crub:crypto key box)
::
++  box-noun
  |=  [key=relay-key val=*]
  ^-  @ux
  (box-atom key (jam val))
::
++  open-noun
  |=  [key=relay-key box=@ux]
  ^-  (unit *)
  =/  raw  (open-atom key box)
  ?~  raw  ~
  =/  rez  (mule |.((cue u.raw)))
  ?:  ?=(%| -.rez)  ~
  `p.rez
::
++  open-header-layer
  |=  [key=relay-key box=header-box]
  ^-  (unit header-layer)
  =/  raw  (open-noun key box)
  ?~  raw  ~
  =/  rez  (mule |.((header-layer u.raw)))
  ?:  ?=(%| -.rez)  ~
  `p.rez
::
++  open-local-header
  |=  [cell=relay-cell our-key=relay-key]
  ^-  (unit header-layer)
  ?:  =(header.cell 0x0)  ~
  =/  hop-key=@ux  (derive-key 'skein-hop' our-key cell-id.cell)
  (open-header-layer hop-key header.cell)
::
::
::  payload helpers
::
++  seal-body
  |=  [body-key=relay-key env=envelope]
  ^-  payload-box
  (box-noun body-key [id.env origin.env target.env sent-at.env payload.env opts.env])
::
++  open-body
  |=  [body-key=relay-key box=payload-box]
  ^-  (unit envelope)
  =/  raw  (open-noun body-key box)
  ?~  raw  ~
  =/  rez  (mule |.((envelope u.raw)))
  ?:  ?=(%| -.rez)  ~
  `p.rez
::
::  cell construction
::
++  build-header
  |=  [hops=(list route-hop) cell-id=@uv body-key=relay-key]
  ^-  header-box
  ?~  hops  0x0
  ::  build from inside out: final layer first
  =/  rev=(list route-hop)  (flop hops)
  ?~  rev  0x0
  ::  final hop layer: next=~ (you are the destination), include body-key
  =/  hop-key=@ux  (derive-key 'skein-hop' key.i.rev cell-id)
  =/  acc=header-box
    (box-noun hop-key [next=~ inner=~ body-key=`body-key delay=delay.i.rev])
  ::  wrap intermediate layers from inside out
  =/  prev-ship=ship  ship.i.rev
  =/  rest=(list route-hop)  t.rev
  |-
  ?~  rest  acc
  =/  hop-key=@ux  (derive-key 'skein-hop' key.i.rest cell-id)
  %=  $
    rest  t.rest
    prev-ship  ship.i.rest
    acc  (box-noun hop-key [`prev-ship `acc ~ delay.i.rest])
  ==
::
++  advance-cell
  |=  [cell=relay-cell layer=header-layer]
  ^-  relay-cell
  =/  inner-box=header-box
    ?~  inner.layer  0x0
    u.inner.layer
  [cell-id.cell inner-box body.cell expiry.cell]
::
++  expiry-for
  |=  [opts=send-options now=@da]
  ^-  (unit @da)
  ?~  ttl.opts  ~
  `(add now u.ttl.opts)
::
++  expired-cell
  |=  [cell=relay-cell now=@da]
  ^-  ?
  ?~  expiry.cell  %.n
  (gth now u.expiry.cell)
::
::  delivery
::
++  deliver-envelope
  |=  [our=ship env=envelope apps=(set app-id) queues=(map app-id (list envelope))]
  ^-  [(list card) (map app-id (list envelope))]
  ~&  [%skein-deliver app.target.env (scot %p ship.origin.env) %to (scot %p ship.target.env)]
  ?.  (~(has in apps) app.target.env)
    ~&  [%skein-deliver %target-not-bound app.target.env]
    :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'target-not-bound'])]~
    queues
  =/  new-queues  (put-queue app.target.env env queues)
  =/  cid=@uv  (cell-id-for id.env origin.env target.env sent-at.env)
  :-  :~  (relay-card [%delivered cid app.target.env])
          (message-card env)
          [%pass /deliver %agent [our app.target.env] %poke %noun !>(payload.env)]
      ==
  new-queues
::
::
::
::  epoch batching
::
++  ensure-epoch-timer
  |=  [mix=mix-state now=@da]
  ^-  [(list card) mix-state]
  ?^  timer.mix
    [~ mix]
  =/  wake=@da  (add now epoch-period)
  :-  [(wait-card /epoch wake)]~
  mix(timer `wake)
::
++  flush-batch
  |=  [batch=(list pending-forward) now=@da]
  ^-  (list card)
  %-  zing
  %+  turn  batch
  |=  pf=pending-forward
  ?:  (expired-cell cell.pf now)
    [(relay-card [%dropped cell-id.cell.pf 'expired-in-batch'])]~
  :~  (relay-card [%forwarded cell-id.cell.pf next.pf])
      (send-cell-card next.pf cell.pf)
  ==
::
++  dispatch-cell
  |=  [next=ship cell=relay-cell delay=(unit @dr) mix=mix-state now=@da]
  ^-  [(list card) mix-state]
  ?~  delay
    :_  mix
    :~  (relay-card [%forwarded cell-id.cell next])
        (send-cell-card next cell)
    ==
  =.  batch.mix  [[next cell] batch.mix]
  (ensure-epoch-timer mix now)
::
::  cover traffic
::
++  cover-send-card
  |=  [our=ship eny=@ relays=(map relay-id relay-descriptor)]
  ^-  (unit card)
  ::  pick a random remote relay as cover traffic target
  =/  others=(list relay-descriptor)
    %+  murn  (relays-list relays)
    |=(d=relay-descriptor ?:(=(ship.d our) ~ `d))
  =/  n=@ud  (lent others)
  ?:  =(n 0)  ~
  =/  target=relay-descriptor  (snag (mod (mug eny) n) others)
  =/  req=send-request  [%cover [ship.target %cover] 'cover' [~ ~ ~]]
  `[%pass /cover %agent [our %skein] %poke %skein-send !>(req)]
::
++  backlog-cards
  |=  [app=app-id backlog=(list envelope)]
  ^-  (list card)
  (turn backlog |=(env=envelope (message-card env)))
::
::  http helpers
::
++  give-http-response
  |=  [eyre-id=@ta status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  [[status headers] body]
::
++  give-json-response
  |=  [eyre-id=@ta jon=json]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  (json-response:gen:server jon)
::
++  stats-json
  |=  $:  our=ship
          apps=(set app-id)
          relays=(map relay-id relay-descriptor)
          seen=(map @uv @da)
          routes=(list route-log)
          mix=mix-state
          channels=(map channel-id (map @p @da))
          our-channels=(map channel-id app-id)
          min-hops=@ud
      ==
  ^-  json
  %-  pairs:enjs:format
  :~  ['ship' s+(scot %p our)]
      ['apps' (numb:enjs:format ~(wyt in apps))]
      ['relays' (numb:enjs:format ~(wyt by relays))]
      ['seen' (numb:enjs:format ~(wyt by seen))]
      ['batch' (numb:enjs:format (lent batch.mix))]
      ['routes' (numb:enjs:format (lent routes))]
      ['hasTimer' b+?=(^ timer.mix)]
      ['channels' (numb:enjs:format ~(wyt by channels))]
      ['ourChannels' (numb:enjs:format ~(wyt by our-channels))]
      ['minHops' (numb:enjs:format min-hops)]
  ==
::
++  relays-json
  |=  relays=(map relay-id relay-descriptor)
  ^-  json
  :-  %a
  %+  turn  ~(tap by relays)
  |=  [rid=relay-id rd=relay-descriptor]
  %-  pairs:enjs:format
  :~  ['relay' s+relay.rd]
      ['ship' s+(scot %p ship.rd)]
      ['hasKey' b+%.y]
      ['weight' (numb:enjs:format weight.rd)]
      :-  'delay'
      ?~  default-delay.rd  ~
      s+(scot %dr u.default-delay.rd)
      :-  'expiry'
      ?~  expiry.rd  ~
      s+(scot %da u.expiry.rd)
  ==
::
++  routes-json
  |=  routes=(list route-log)
  ^-  json
  :-  %a
  %+  turn  routes
  |=  rl=route-log
  %-  pairs:enjs:format
  :~  ['cellId' s+(scot %uv cell-id.rl)]
      ['routeId' s+(scot %uv route-id.rl)]
      :-  'target'
      s+(crip "{(trip (scot %p ship.target.rl))}/{(trip app.target.rl)}")
      ['hops' a+(turn hops.rl |=(s=ship s+(scot %p s)))]
      :-  'selectedAt'
      (numb:enjs:format (div (sub selected-at.rl ~1970.1.1) ~s1))
  ==
::
++  apps-json
  |=  apps=(set app-id)
  ^-  json
  a+(turn ~(tap in apps) |=(a=app-id s+a))
::
++  batch-json
  |=  batch=(list pending-forward)
  ^-  json
  :-  %a
  %+  turn  batch
  |=  pf=pending-forward
  %-  pairs:enjs:format
  :~  ['next' s+(scot %p next.pf)]
  ==
::
++  channels-json
  |=  [channels=(map channel-id (map @p @da)) our-channels=(map channel-id app-id)]
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'hosted'
      :-  %a
      %+  turn  ~(tap by channels)
      |=  [cid=channel-id members=(map @p @da)]
      %-  pairs:enjs:format
      :~  ['channel' s+cid]
          ['members' (numb:enjs:format ~(wyt by members))]
          ['ships' a+(turn ~(tap in ~(key by members)) |=(s=ship s+(scot %p s)))]
      ==
    :-  'joined'
    :-  %a
    %+  turn  ~(tap by our-channels)
    |=  [cid=channel-id app=app-id]
    %-  pairs:enjs:format
    :~  ['channel' s+cid]
        ['app' s+app]
    ==
  ==
::
++  index-html
  ^-  @t
  '''
  <!DOCTYPE html>
  <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>skein</title>
  <style>
  * { margin: 0; padding: 0; box-sizing: border-box }
  body { font-family: monospace; background: #111; color: #ccc; padding: 24px; max-width: 900px; margin: 0 auto }
  h1 { color: #fff; margin-bottom: 4px; font-size: 20px }
  .sub { color: #666; margin-bottom: 20px; font-size: 13px }
  .cards { display: flex; gap: 12px; margin-bottom: 20px; flex-wrap: wrap }
  .card { background: #1a1a1a; border: 1px solid #333; border-radius: 6px; padding: 14px; min-width: 110px }
  .card .n { font-size: 24px; color: #fff; font-weight: bold }
  .card .l { font-size: 11px; color: #666; margin-top: 2px }
  h2 { color: #fff; font-size: 14px; margin: 16px 0 6px }
  table { width: 100%; border-collapse: collapse; font-size: 12px }
  th { text-align: left; color: #666; border-bottom: 1px solid #333; padding: 5px 8px; font-weight: normal }
  td { padding: 5px 8px; border-bottom: 1px solid #1e1e1e; word-break: break-all }
  .tag { display: inline-block; background: #222; border: 1px solid #333; border-radius: 3px; padding: 2px 8px; font-size: 12px; margin: 2px }
  .ok { color: #5b5 } .dim { color: #555 }
  .trunc { max-width: 120px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: inline-block; vertical-align: bottom }
  #status { font-size: 11px; color: #444; margin-top: 12px }
  </style></head><body>
  <h1>skein</h1>
  <div class="sub" id="ship"></div>
  <div class="cards" id="stats"></div>
  <h2>relays</h2>
  <table id="relays"><thead><tr><th>id</th><th>ship</th><th>key</th><th>weight</th><th>delay</th><th>expiry</th></tr></thead><tbody></tbody></table>
  <h2>recent routes</h2>
  <table id="routes"><thead><tr><th>cell</th><th>target</th><th>hops</th><th>time</th></tr></thead><tbody></tbody></table>
  <h2>bound apps</h2>
  <div id="apps"></div>
  <div id="status"></div>
  <script>
  var B = "/apps/skein/api";
  function el(id) { return document.getElementById(id) }
  function qs(sel) { return document.querySelector(sel) }
  function cd(n, label) {
    return "<div class=\"card\"><div class=\"n\">" + n + "</div><div class=\"l\">" + label + "</div></div>";
  }
  async function load() {
    try {
      var res = await Promise.all(
        ["/stats", "/relays", "/routes", "/apps"].map(function(p) {
          return fetch(B + p).then(function(r) { return r.json() });
        })
      );
      var s = res[0], rl = res[1], rt = res[2], ap = res[3];
      el("ship").textContent = s.ship || "";
      el("stats").innerHTML =
        cd(s.apps, "bound apps") + cd(s.relays, "relays") +
        cd(s.seen, "seen cache") + cd(s.batch, "batch queue") +
        cd(s.routes, "routes logged") +
        cd(s.hasTimer ? "on" : "off", "epoch timer");
      var rb = qs("#relays tbody");
      if (!rl.length) {
        rb.innerHTML = "<tr><td colspan=\"6\" class=\"dim\">no relays configured</td></tr>";
      } else {
        rb.innerHTML = rl.map(function(r) {
          return "<tr><td>" + r.relay + "</td><td>" + r.ship + "</td><td>" +
            (r.hasKey ? "<span class=\"ok\">yes</span>" : "<span class=\"dim\">none</span>") +
            "</td><td>" + r.weight + "</td><td class=\"dim\">" + (r.delay || "-") +
            "</td><td class=\"dim\">" + (r.expiry || "-") + "</td></tr>";
        }).join("");
      }
      var rr = qs("#routes tbody");
      if (!rt.length) {
        rr.innerHTML = "<tr><td colspan=\"4\" class=\"dim\">no routes yet</td></tr>";
      } else {
        rr.innerHTML = rt.map(function(r) {
          return "<tr><td><span class=\"trunc\">" + r.cellId + "</span></td><td>" +
            r.target + "</td><td>" + r.hops.join(" &gt; ") + "</td><td class=\"dim\">" +
            new Date(r.selectedAt * 1000).toLocaleString() + "</td></tr>";
        }).join("");
      }
      el("apps").innerHTML = ap.length
        ? ap.map(function(a) { return "<span class=\"tag\">" + a + "</span>" }).join(" ")
        : "<span class=\"dim\">none</span>";
      el("status").textContent = "updated " + new Date().toLocaleTimeString();
    } catch(e) { el("status").textContent = "error: " + e.message }
  }
  load(); setInterval(load, 10000);
  </script></body></html>
  '''
--
::
%+  verb  |
%-  agent:dbug
=|  current-state
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  =.  our-key.state  (shaz (jam [%skein-relay-key our.bowl eny.bowl now.bowl]))
  =.  next-id.state  1
  =.  apps.state     (sy ~[%cover])
  =.  queues.state   ~
  =.  relays.state   ~
  =.  seen.state     ~
  =.  recent-routes.state  ~
  =.  mix.state      [~ ~]
  =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
  ::  bootstrap: subscribe to default relay to discover network
  =/  default-ship=ship  ~sovsef-risfex-sitful-hatred
  =/  boot-cards=(list card)
    ?:  =(default-ship our.bowl)  ~
    :~  [%pass /relay/sub/(scot %p default-ship) %agent [default-ship %skein] %watch /relay/pool]
    ==
  =/  sub-cards=(list card)  (discovery-sub-cards our.bowl relays.state wex.bowl)
  :_  this
  ;:  weld
    timer-cards
    boot-cards
    sub-cards
    ^-  (list card)
    :~  [%pass /eyre/takeover %arvo %e %connect [~ /apps/skein] dap.bowl]
        [%pass /eyre/takeover %arvo %e %disconnect [~ /apps/skein]]
        [%pass /eyre/connect %arvo %e %connect [~ /apps/skein/api] dap.bowl]
    ==
  ==
::
++  on-save
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  |^
  ?:  =(-.q.old 14)
    =/  saved  !<(state-14 old)
    =.  state  saved
    finish
  ?:  =(-.q.old 13)
    =/  saved  !<(state-13 old)
    =.  state
      :*  %14
          next-id.saved
          apps.saved
          queues.saved
          relays.saved
          seen.saved
          recent-routes.saved
          mix.saved
          our-key.saved
          channels.saved
          our-channels.saved
          default-min-hops
      ==
    finish
  ?:  =(-.q.old 12)
    =/  saved  !<(state-12 old)
    =.  state
      :*  %14
          next-id.saved
          apps.saved
          queues.saved
          relays.saved
          seen.saved
          recent-routes.saved
          mix.saved
          our-key.saved
          ~    ::  channels
          ~    ::  our-channels
          default-min-hops
      ==
    finish
  ::  incompatible older state — fresh start
  =/  new-key=relay-key  (shaz (jam [%skein-relay-key our.bowl eny.bowl now.bowl]))
  =.  state  [%14 1 (sy ~[%cover]) ~ ~ ~ ~ [~ ~] new-key ~ ~ default-min-hops]
  finish
  ::
  ++  finish
    =.  apps.state  (~(put in apps.state) %cover)
    ::  remove self from relays if present
    =.  relays.state  (~(del by relays.state) (scot %p our.bowl))
    =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    ::  bootstrap: subscribe to default relay to discover network
    =/  default-ship=ship  ~sovsef-risfex-sitful-hatred
    =/  boot-cards=(list card)
      ?:  =(default-ship our.bowl)  ~
      =/  seg=@ta  (scot %p default-ship)
      ?:  (~(has by wex.bowl) [/relay/sub/[seg] default-ship %skein])  ~
      :~  [%pass /relay/sub/[seg] %agent [default-ship %skein] %watch /relay/pool]
      ==
    =/  sub-cards=(list card)  (discovery-sub-cards our.bowl relays.state wex.bowl)
    ::  re-subscribe to channels on known relays
    =/  channel-cards=(list card)
      %-  zing
      %+  turn  ~(tap by our-channels.state)
      |=  [cid=channel-id app=app-id]
      %+  murn  (relays-list relays.state)
      |=  rd=relay-descriptor
      ?:  =(ship.rd our.bowl)  ~
      =/  seg=@ta  (scot %p ship.rd)
      ?:  (~(has by wex.bowl) [/channel/sub/[seg]/[cid] ship.rd %skein])  ~
      `(channel-sub-card ship.rd cid)
    :_  this
    ;:  weld
      timer-cards
      boot-cards
      sub-cards
      channel-cards
      ^-  (list card)
      :~  [%pass /eyre/takeover %arvo %e %connect [~ /apps/skein] dap.bowl]
          [%pass /eyre/takeover %arvo %e %disconnect [~ /apps/skein]]
          [%pass /eyre/connect %arvo %e %connect [~ /apps/skein/api] dap.bowl]
      ==
    ==
  --
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ~?  !=(mark %handle-http-request)  [%skein-poke mark src.bowl]
  |^
  ?+  mark  (on-poke:def mark vase)
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    (handle-http eyre-id req)
  ::
      %skein-admin
    ?>  =(our src):bowl
    =/  act  !<(admin-action vase)
    (exec-admin-action act)
  ::
      %skein-send
    ?>  =(our src):bowl
    =/  req  !<(send-request vase)
    ?.  (~(has in apps.state) from.req)
      ~&  [%skein-send %app-not-bound from.req]
      `this
    =/  resolved-route=(unit route)
      ?~  route.opts.req
        ?:(=(ship.to.req our.bowl) ~ (select-route our.bowl to.req relays.state now.bowl eny.bowl min-hops.state))
      `(hydrate-route u.route.opts.req relays.state)
    =/  resolved-opts=send-options  [resolved-route reply-blocks.opts.req ttl.opts.req]
    =/  env=envelope
      [next-id.state (local-endpoint from.req our.bowl) to.req now.bowl payload.req resolved-opts]
    =.  next-id.state  +(next-id.state)
    ::  local loopback
    ?:  ?&(=(ship.to.req our.bowl) ?=(~ resolved-route))
      ~&  [%skein-send %loopback from.req app.to.req]
      =^  cards  queues.state  (deliver-envelope our.bowl env apps.state queues.state)
      [cards this]
    ::  no route
    ?~  resolved-route
      ~&  [%skein-send %no-route from.req (scot %p ship.to.req) app.to.req]
      :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'no-route'])]~
      this
    =/  full-route=(list ship)  (route-ships to.req resolved-opts)
    =/  actual-hops=@ud  (lent hops.u.resolved-route)
    =/  intermediate=@ud  ?:(=(actual-hops 0) 0 (dec actual-hops))
    ~&  [%skein-send %routing from.req (scot %p ship.to.req) %via actual-hops %hops]
    ~?  (lth intermediate min-hops.state)  [%skein-send %degraded-route %wanted min-hops.state %got intermediate]
    ?~  full-route
      :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'no-route'])]~
      this
    =/  cell-id=@uv  (cell-id-for id.env origin.env target.env sent-at.env)
    =/  body-key=relay-key  (shaz (jam [%skein-body eny.bowl cell-id]))
    =/  body=payload-box  (seal-body body-key env)
    =/  header=header-box
      (build-header hops.u.resolved-route cell-id body-key)
    =/  cell=relay-cell
      [cell-id header body (expiry-for opts.req now.bowl)]
    =/  selected=route-log
      [cell-id route-id.u.resolved-route to.req (route-ships to.req resolved-opts) now.bowl]
    =.  recent-routes.state  (trim-routes [selected recent-routes.state])
    =/  first-hop=(unit route-hop)  (route-head hops.u.resolved-route)
    =/  first-delay=(unit @dr)
      ?~  first-hop  ~
      delay.u.first-hop
    =^  cards  mix.state
      (dispatch-cell i.full-route cell first-delay mix.state now.bowl)
    =/  base-cards=(list card)
      :~  (relay-card [%sent cell-id to.req])
          (relay-card [%route-selected cell-id u.resolved-route])
      ==
    [(weld base-cards cards) this]
  ::
      %skein-cell
    =/  cell  !<(relay-cell vase)
    ::  drop expired and replayed cells
    ?:  (expired-cell cell now.bowl)
      :_  this
      [(relay-card [%dropped cell-id.cell 'expired'])]~
    ?:  (seen-step cell seen.state)
      :_  this
      [(relay-card [%dropped cell-id.cell 'replay'])]~
    =.  seen.state  (remember-step cell seen.state now.bowl)
    =.  seen.state  (prune-seen seen.state now.bowl)
    ::  decrypt our header layer
    =/  layer=(unit header-layer)
      (open-local-header cell our-key.state)
    ?~  layer
      :_  this
      [(relay-card [%dropped cell-id.cell 'undecryptable'])]~
    =/  base=(list card)
      [(relay-card [%received cell-id.cell src.bowl])]~
    ::  check if we are the final destination
    ?~  next.u.layer
      ::  final destination — decrypt body
      ?~  body-key.u.layer
        [(weld base [(relay-card [%dropped cell-id.cell 'no-body-key'])]~) this]
      =/  env=(unit envelope)
        (open-body u.body-key.u.layer body.cell)
      ?~  env
        [(weld base [(relay-card [%dropped cell-id.cell 'body-unopenable'])]~) this]
      ?.  =(ship.target.u.env our.bowl)
        [(weld base [(relay-card [%dropped cell-id.cell 'wrong-target'])]~) this]
      =^  cards  queues.state
        (deliver-envelope our.bowl u.env apps.state queues.state)
      [(weld base cards) this]
    ::  forward to next hop — only know immediate next, nothing else
    =/  next-cell=relay-cell  (advance-cell cell u.layer)
    =^  cards  mix.state
      (dispatch-cell u.next.u.layer next-cell delay.u.layer mix.state now.bowl)
    [(weld base cards) this]
  ==
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  rl=request-line:server  (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.rl
    ?.  ?=([%apps %skein %api *] site)
      :_  this
      (give-http-response eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    =/  pax=(list @t)  t.t.t.site
    ?.  authenticated.req
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (login-redirect:gen:server request.req)
    ?+  method.request.req
      :_  this
      (give-http-response eyre-id 405 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'method not allowed')))
    ::
        %'GET'
      (handle-get eyre-id pax)
    ::
        %'POST'
      (handle-post eyre-id pax body.request.req)
    ==
  ::
  ++  handle-get
    |=  [eyre-id=@ta pax=(list @t)]
    ^-  (quip card _this)
    ?+  pax
      :_  this
      (give-http-response eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    ::
        [%stats ~]
      :_  this
      (give-json-response eyre-id (stats-json our.bowl apps.state relays.state seen.state recent-routes.state mix.state channels.state our-channels.state min-hops.state))
    ::
        [%relays ~]
      :_  this
      (give-json-response eyre-id (relays-json relays.state))
    ::
        [%routes ~]
      :_  this
      (give-json-response eyre-id (routes-json recent-routes.state))
    ::
        [%apps ~]
      :_  this
      (give-json-response eyre-id (apps-json apps.state))
    ::
        [%batch ~]
      :_  this
      (give-json-response eyre-id (batch-json batch.mix.state))
    ::
        [%channels ~]
      :_  this
      (give-json-response eyre-id (channels-json channels.state our-channels.state))
    ==
  ::
  ++  handle-post
    |=  [eyre-id=@ta pax=(list @t) body=(unit octs)]
    ^-  (quip card _this)
    ?.  ?=(~ pax)
      :_  this
      (give-http-response eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    ?~  body
      :_  this
      (give-http-response eyre-id 400 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'empty body')))
    =/  jon=(unit json)  (de:json:html q.u.body)
    ?~  jon
      :_  this
      (give-http-response eyre-id 400 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'bad json')))
    =/  act  (parse-api-action u.jon)
    ?~  act
      :_  this
      (give-http-response eyre-id 400 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'unknown action')))
    =^  cards  this
      (exec-admin-action u.act)
    :_  this
    %+  weld  cards
    (give-json-response eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::
  ++  parse-api-action
    |=  jon=json
    ^-  (unit admin-action)
    =/  act=@t
      ((ot:dejs:format ~[['action' so:dejs:format]]) jon)
    ?+  act  ~
        %'put-relay'
      =/  parsed
        %.  jon
        %-  ot:dejs:format
        :~  ['ship' (se:dejs:format %p)]
        ==
      ::  subscribe to the ship to discover its key and relays
      `[%discover-relay ship=parsed]
    ::
        %'drop-relay'
      =/  rid=relay-id
        ((ot:dejs:format ~[['relay' so:dejs:format]]) jon)
      `[%drop-relay rid]
    ::
        %'clear-seen'
      `[%clear-seen ~]
    ::
        %'bind-app'
      =/  app=app-id
        ((ot:dejs:format ~[['app' so:dejs:format]]) jon)
      `[%bind app]
    ::
        %'unbind-app'
      =/  app=app-id
        ((ot:dejs:format ~[['app' so:dejs:format]]) jon)
      `[%unbind app]
    ::
        %'join-channel'
      =/  f  (ot:dejs:format ~[['channel' so:dejs:format] ['app' so:dejs:format]])
      =/  [channel=@t app=@t]  (f jon)
      `[%join-channel `@tas`channel `@tas`app]
    ::
        %'leave-channel'
      =/  channel=@t
        ((ot:dejs:format ~[['channel' so:dejs:format]]) jon)
      `[%leave-channel `@tas`channel]
    ::
        %'set-min-hops'
      =/  n=@ud
        ((ot:dejs:format ~[['n' ni:dejs:format]]) jon)
      `[%set-min-hops n]
    ==
  ::
  ++  exec-admin-action
    |=  act=admin-action
    ^-  (quip card _this)
    ?-  -.act
        %bind
      =.  apps.state  (~(put in apps.state) app.act)
      :-  [(relay-card [%bound app.act])]~
      this
    ::
        %unbind
      ?:  =(app.act %cover)  `this
      =.  apps.state    (~(del in apps.state) app.act)
      =.  queues.state  (~(del by queues.state) app.act)
      :-  [(relay-card [%unbound app.act])]~
      this
    ::
        %clear
      =.  queues.state  (~(del by queues.state) app.act)
      :-  [(relay-card [%cleared app.act])]~
      this
    ::
        %put-relay
      =.  relays.state  (~(put by relays.state) relay.descriptor.act descriptor.act)
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-key.state)
      :-  :~  (relay-card [%relay-added descriptor.act])
              (pool-fact-card [our-rd (relays-list relays.state)])
          ==
      this
    ::
        %drop-relay
      =.  relays.state  (~(del by relays.state) relay.act)
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-key.state)
      :-  :~  (relay-card [%relay-removed relay.act])
              (pool-fact-card [our-rd (relays-list relays.state)])
          ==
      this
    ::
        %discover-relay
      ::  subscribe to a ship to discover its key and relay pool
      ?:  =(ship.act our.bowl)  `this
      ?:  (~(has in (known-ships relays.state)) ship.act)  `this
      :_  this
      :~  [%pass /relay/sub/(scot %p ship.act) %agent [ship.act %skein] %watch /relay/pool]
      ==
    ::
        %clear-seen
      =.  seen.state  ~
      :-  [(relay-card [%replay-cleared ~])]~
      this
    ::
        %join-channel
      =.  our-channels.state  (~(put by our-channels.state) channel.act app.act)
      ::  subscribe to all known relays
      =/  sub-cards=(list card)
        %+  murn  (relays-list relays.state)
        |=  rd=relay-descriptor
        ?:  =(ship.rd our.bowl)  ~
        =/  seg=@ta  (scot %p ship.rd)
        ?:  (~(has by wex.bowl) [/channel/sub/[seg]/[channel.act] ship.rd %skein])  ~
        `(channel-sub-card ship.rd channel.act)
      :_  this
      [(relay-card [%channel-joined channel.act]) sub-cards]
    ::
        %leave-channel
      =/  cid  channel.act
      =.  our-channels.state  (~(del by our-channels.state) cid)
      ::  unsubscribe from all relays
      =/  unsub-cards=(list card)
        %+  murn  (relays-list relays.state)
        |=  rd=relay-descriptor
        ?:  =(ship.rd our.bowl)  ~
        =/  seg=@ta  (scot %p ship.rd)
        ?.  (~(has by wex.bowl) [/channel/sub/[seg]/[cid] ship.rd %skein])  ~
        `(channel-unsub-card ship.rd cid)
      :_  this
      [(relay-card [%channel-left cid]) unsub-cards]
    ::
        %set-min-hops
      =.  min-hops.state  n.act
      ~&  [%skein %min-hops-set n.act]
      `this
    ==
  --
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %state ~]
    ``noun+!>(state)
  ::
      [%x %app * ~]
    =/  app=app-id  i.t.t.path
    ``noun+!>([(~(has in apps.state) app) (flop (queue-for app queues.state))])
  ::
      [%x %descriptors ~]
    ``noun+!>((relays-list relays.state))
  ::
      [%x %routes ~]
    ``noun+!>(recent-routes.state)
  ::
      [%x %stats ~]
    =/  s
      :*  apps=~(wyt in apps.state)
          relays=~(wyt by relays.state)
          seen=~(wyt by seen.state)
          routes=(lent recent-routes.state)
          batch=(lent batch.mix.state)
          has-timer=?=(^ timer.mix.state)
      ==
    ``noun+!>(s)
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%relay %events ~]
    `this
  ::
      [%relay %pool ~]
    ::  send our pool including our own descriptor so subscriber gets our key
    =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-key.state)
    =/  full-pool=(list relay-descriptor)  [our-rd (relays-list relays.state)]
    ::  subscribe back to learn their key (if not already known)
    =/  sub-ship=ship  src.bowl
    =/  seg=@ta  (scot %p sub-ship)
    =/  back-cards=(list card)
      ?:  =(sub-ship our.bowl)  ~
      ?:  (~(has in (known-ships relays.state)) sub-ship)  ~
      ?:  (~(has by wex.bowl) [/relay/sub/[seg] sub-ship %skein])  ~
      :~  [%pass /relay/sub/[seg] %agent [sub-ship %skein] %watch /relay/pool]
      ==
    :_  this
    :_  back-cards
    [%give %fact ~ %skein-relay-pool !>(`(list relay-descriptor)`full-pool)]
  ::
      [%channel @ ~]
    =/  cid=channel-id  i.t.path
    =/  members=(map @p @da)  (~(gut by channels.state) cid ~)
    ::  add subscriber to directory
    =.  members  (~(put by members) src.bowl now.bowl)
    =.  channels.state  (~(put by channels.state) cid members)
    =/  member-list=(list @p)  ~(tap in ~(key by members))
    ::  send member list to new subscriber
    ::  notify all subscribers (including new) of new join
    :_  this
    :~  [%give %fact ~ %skein-channel !>(`channel-update`[%members cid member-list])]
        [%give %fact [/channel/[cid]]~ %skein-channel !>(`channel-update`[%join cid src.bowl])]
    ==
  ::
      [%app * %inbox ~]
    =/  app=app-id  i.t.path
    ?.  (~(has in apps.state) app)
      `this
    [(backlog-cards app (flop (queue-for app queues.state))) this]
  ::
      [%http-response *]
    `this
  ==
::
++  on-leave
  |=  =path
  ^-  (quip card _this)
  ?+  path  `this
      [%channel @ ~]
    =/  cid=channel-id  i.t.path
    =/  members=(map @p @da)  (~(gut by channels.state) cid ~)
    ?.  (~(has by members) src.bowl)  `this
    =.  members  (~(del by members) src.bowl)
    =.  channels.state
      ?:  =(~ members)
        (~(del by channels.state) cid)
      (~(put by channels.state) cid members)
    :_  this
    ?:  =(~ members)  ~
    :~  [%give %fact [/channel/[cid]]~ %skein-channel !>(`channel-update`[%leave cid src.bowl])]
    ==
  ==
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:def wire sign)
      [%relay %sub @ ~]
    ?+  -.sign  (on-agent:def wire sign)
        %fact
      ?.  =(%skein-relay-pool p.cage.sign)  `this
      =/  pool=(list relay-descriptor)  !<((list relay-descriptor) q.cage.sign)
      =/  [new-rds=(list relay-descriptor) new-relays=(map relay-id relay-descriptor)]
        (merge-relays our.bowl pool relays.state)
      ?~  new-rds  `this
      ::  we learned new relays -- update state, notify subscribers, subscribe to new ones
      =.  relays.state  new-relays
      =/  new-sub-cards=(list card)
        %+  murn  new-rds
        |=  rd=relay-descriptor
        ?:  =(ship.rd our.bowl)  ~
        =/  seg=@ta  (scot %p ship.rd)
        ?:  (~(has by wex.bowl) [/relay/sub/[seg] ship.rd %skein])  ~
        `(subscribe-relay-card our.bowl rd)
      ::  auto-subscribe to our channels on new relays
      =/  channel-sub-cards=(list card)
        %-  zing
        %+  turn  ~(tap by our-channels.state)
        |=  [cid=channel-id app=app-id]
        %+  murn  new-rds
        |=  rd=relay-descriptor
        ?:  =(ship.rd our.bowl)  ~
        =/  seg=@ta  (scot %p ship.rd)
        ?:  (~(has by wex.bowl) [/channel/sub/[seg]/[cid] ship.rd %skein])  ~
        `(channel-sub-card ship.rd cid)
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-key.state)
      :_  this
      ;:  weld
        [(pool-fact-card [our-rd (relays-list relays.state)])]~
        new-sub-cards
        channel-sub-cards
      ==
    ::
        %kick
      ::  re-subscribe to this relay
      =/  who=ship  (slav %p i.t.t.wire)
      :_  this
      :~  [%pass wire %agent [who %skein] %watch /relay/pool]
      ==
    ::
        %watch-ack
      ?~  p.sign  `this
      ::  subscription rejected — will retry on next epoch
      ((slog u.p.sign) `this)
    ==
  ::
      [%channel %sub @ @ ~]
    =/  relay-ship=ship  (slav %p i.t.t.wire)
    =/  cid=channel-id  i.t.t.t.wire
    ?+  -.sign  (on-agent:def wire sign)
        %fact
      ?.  =(%skein-channel p.cage.sign)  `this
      =/  upd  !<(channel-update q.cage.sign)
      =/  app=(unit app-id)  (~(get by our-channels.state) cid)
      ?~  app  `this
      ::  forward channel update to app as tagged noun
      =/  tagged=*
        ?-  -.upd
          %join     [%channel-join channel.upd ship.upd]
          %leave    [%channel-leave channel.upd ship.upd]
          %members  [%channel-members channel.upd ships.upd]
        ==
      :_  this
      :~  [%pass /channel/notify %agent [our.bowl u.app] %poke %noun !>(tagged)]
      ==
    ::
        %kick
      ::  re-subscribe to this relay's channel
      :_  this
      :~  [%pass wire %agent [relay-ship %skein] %watch /channel/[cid]]
      ==
    ::
        %watch-ack
      ?~  p.sign  `this
      ((slog u.p.sign) `this)
    ==
  ::
      [%deliver *]
    `this
  ::
      [%channel *]
    `this
  ==
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign-arvo)
      [%eyre *]
    `this
  ::
      [%epoch ~]
    ?.  ?=(%wake +<.sign-arvo)
      [~ this]
    ?^  error.sign-arvo
      =.  mix.state  [~ ~]
      =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
      [timer-cards this]
    ::  flush pending batch
    =/  flush-cards=(list card)  (flush-batch batch.mix.state now.bowl)
    =.  mix.state  [~ ~]
    ::  maybe generate cover traffic
    =/  cover-cards=(list card)
      ?.  ?&  (gth ~(wyt by relays.state) 1)
              (lth (mod (mug eny.bowl) cover-chance) 1)
          ==
        ~
      =/  cc  (cover-send-card our.bowl eny.bowl relays.state)
      ?~(cc ~ [u.cc]~)
    ::  re-attempt bootstrap if we have no relays and no pending sub
    =/  bootstrap-cards=(list card)
      ?.  =(~ relays.state)  ~
      =/  default-ship=ship  ~sovsef-risfex-sitful-hatred
      ?:  =(default-ship our.bowl)  ~
      =/  seg=@ta  (scot %p default-ship)
      ?:  (~(has by wex.bowl) [/relay/sub/[seg] default-ship %skein])  ~
      :~  [%pass /relay/sub/[seg] %agent [default-ship %skein] %watch /relay/pool]
      ==
    ::  re-arm epoch timer
    =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    [(zing ~[flush-cards cover-cards bootstrap-cards timer-cards]) this]
  ::
      [%delay *]
    ::  legacy timer from state-2, discard
    [~ this]
  ::
      [%cell *]
    ::  ack from poke delivery, ignore
    [~ this]
  ::
      [%cover ~]
    ::  ack from cover self-poke, ignore
    [~ this]
  ==
++  on-fail   on-fail:def
--
