/-  *skein
/+  dbug, verb, default-agent
|%
::  configuration
::
++  seen-ttl  ~h1
++  max-routes  100
++  epoch-period  ~s30
++  min-hops  2
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
+$  state-0
  $:  %0
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
  ==
::
+$  state-1
  $:  %1
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(set relay-step)
      recent-routes=(list route-log)
  ==
::
+$  old-pending  [wake=@da next=ship cell=relay-cell]
::
+$  state-2
  $:  %2
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(set relay-step)
      recent-routes=(list route-log)
      pending=(map path old-pending)
  ==
::
+$  state-3
  $:  %3
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(map relay-step @da)
      recent-routes=(list route-log)
      mix=mix-state
  ==
::
+$  persisted-state
  $%  state-0
      state-1
      state-2
      state-3
  ==
::
+$  current-state  state-3
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
++  wait-card
  |=  [wire=path when=@da]
  ^-  card
  [%pass wire %arvo %b %wait when]
::
::  replay detection
::
++  relay-step-for
  |=  cell=relay-cell
  ^-  relay-step
  [cell-id.cell remaining.cell]
::
++  seen-step
  |=  [cell=relay-cell seen=(map relay-step @da)]
  ^-  ?
  (~(has by seen) (relay-step-for cell))
::
++  remember-step
  |=  [cell=relay-cell seen=(map relay-step @da) now=@da]
  ^-  (map relay-step @da)
  (~(put by seen) (relay-step-for cell) now)
::
++  prune-seen
  |=  [seen=(map relay-step @da) now=@da]
  ^-  (map relay-step @da)
  =/  cutoff=@da  (sub now seen-ttl)
  %-  ~(rep by seen)
  |=  [[step=relay-step at=@da] out=(map relay-step @da)]
  ?:  (lth at cutoff)
    out
  (~(put by out) step at)
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
  =/  key=(unit relay-key)
    ?~(key.hop key.u.descriptor key.hop)
  =/  delay=(unit @dr)
    ?~(delay.hop default-delay.u.descriptor delay.hop)
  [ship.hop relay.hop key delay]
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
  |=  [relays=(map relay-id relay-descriptor) target=ship now=@da]
  ^-  (list relay-descriptor)
  %+  murn  (relays-list relays)
  |=  d=relay-descriptor
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
  |=  [target=endpoint relays=(map relay-id relay-descriptor) now=@da eny=@]
  ^-  (unit route)
  =/  candidates=(list relay-descriptor)
    (shuffle-relays eny (eligible-relays relays ship.target now))
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
++  local-relays
  |=  [relays=(map relay-id relay-descriptor) our=ship now=@da]
  ^-  (list relay-descriptor)
  %+  murn  (relays-list relays)
  |=  d=relay-descriptor
  ?.  ?&(=(ship.d our) (live-relay d now))  ~
  `d
::
++  open-local-header
  |=  [cell=relay-cell relays=(map relay-id relay-descriptor) our=ship now=@da]
  ^-  (unit header-layer)
  ?:  =(header.cell 0x0)  ~
  =/  locals=(list relay-descriptor)  (local-relays relays our now)
  |-  ^-  (unit header-layer)
  ?~  locals  ~
  ?~  key.i.locals
    $(locals t.locals)
  =/  opened=(unit header-layer)
    (open-header-layer (derive-key 'skein-hop' u.key.i.locals cell-id.cell) header.cell)
  ?~  opened
    $(locals t.locals)
  opened
::
++  payload-key-for
  |=  [cell-id=@uv target=endpoint route=route]
  ^-  (unit relay-key)
  =/  last=(unit route-hop)  (route-last-hop hops.route)
  ?~  last  ~
  ?:  ?|(!=(ship.u.last ship.target) ?=(~ key.u.last))
    ~
  `(derive-key 'skein-body' u.key.u.last cell-id)
::
::  payload helpers
::
++  box-payload
  |=  payload=*
  ^-  payload-box
  (jam payload)
::
++  safe-unbox-payload
  |=  box=payload-box
  ^-  (unit *)
  =/  rez  (mule |.((cue box)))
  ?:  ?=(%| -.rez)  ~
  `p.rez
::
++  seal-payload
  |=  [body-key=(unit relay-key) payload=*]
  ^-  payload-box
  ?~  body-key
    (box-payload payload)
  (box-noun u.body-key payload)
::
++  payload-from-cell
  |=  [cell=relay-cell body-key=(unit relay-key)]
  ^-  (unit *)
  ?~  body-key
    (safe-unbox-payload body.cell)
  (open-noun u.body-key body.cell)
::
::  cell construction
::
++  build-header
  |=  [full=(list ship) hops=(list route-hop) cell-id=@uv body-key=(unit relay-key)]
  ^-  header-box
  ?~  hops  0x0
  ?~  full  0x0
  ?~  key.i.hops  0x0
  ?~  t.hops
    (box-noun (derive-key 'skein-hop' u.key.i.hops cell-id) [t.full ~ body-key delay.i.hops])
  =/  inner=header-box  $(full t.full, hops t.hops)
  ?:  =(inner 0x0)  0x0
  (box-noun (derive-key 'skein-hop' u.key.i.hops cell-id) [t.full `inner ~ delay.i.hops])
::
++  advance-cell
  |=  [cell=relay-cell layer=header-layer]
  ^-  relay-cell
  =/  inner-box=header-box
    ?~  inner.layer  0x0
    u.inner.layer
  :*  cell-id.cell  id.cell  origin.cell  target.cell
      sent-at.cell  remaining.layer  inner-box  body.cell
      opts.cell  expiry.cell
  ==
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
  |=  [env=envelope apps=(set app-id) queues=(map app-id (list envelope))]
  ^-  [(list card) (map app-id (list envelope))]
  ?.  (~(has in apps) app.target.env)
    :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'target-not-bound'])]~
    queues
  =/  new-queues  (put-queue app.target.env env queues)
  :-  :~  (relay-card [%delivered (cell-id-for id.env origin.env target.env sent-at.env) app.target.env])
          (message-card env)
      ==
  new-queues
::
++  deliver-cell
  |=  [cell=relay-cell payload=* apps=(set app-id) queues=(map app-id (list envelope))]
  ^-  [(list card) (map app-id (list envelope))]
  =/  env=envelope
    [id.cell origin.cell target.cell sent-at.cell payload opts.cell]
  ?.  (~(has in apps) app.target.cell)
    :-  [(relay-card [%dropped cell-id.cell 'target-not-bound'])]~
    queues
  =/  new-queues  (put-queue app.target.cell env queues)
  :-  :~  (relay-card [%delivered cell-id.cell app.target.cell])
          (message-card env)
      ==
  new-queues
::
++  forward-target
  |=  cell=relay-cell
  ^-  (unit [next=ship cell=relay-cell])
  ?~  remaining.cell  ~
  =/  next-cell=relay-cell
    :*  cell-id.cell  id.cell  origin.cell  target.cell
        sent-at.cell  t.remaining.cell  header.cell  body.cell
        opts.cell  expiry.cell
    ==
  `[i.remaining.cell next-cell]
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
  |=  [our=ship]
  ^-  card
  =/  req=send-request  [%cover [our %cover] 'cover' [~ ~ ~]]
  [%pass /cover %agent [our %skein] %poke %skein-send !>(req)]
::
++  backlog-cards
  |=  [app=app-id backlog=(list envelope)]
  ^-  (list card)
  (turn backlog |=(env=envelope (message-card env)))
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
  =.  next-id.state  1
  =.  apps.state     (sy ~[%cover])
  =.  queues.state   ~
  =.  relays.state   ~
  =.  seen.state     ~
  =.  recent-routes.state  ~
  =.  mix.state      [~ ~]
  =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
  [timer-cards this]
::
++  on-save
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  saved=persisted-state  !<(persisted-state old)
  ?-  -.saved
      %0
    =.  state  [%3 next-id.saved apps.saved queues.saved ~ ~ ~ [~ ~]]
    =.  apps.state  (~(put in apps.state) %cover)
    =^  cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    [cards this]
  ::
      %1
    =.  state  [%3 next-id.saved apps.saved queues.saved relays.saved ~ recent-routes.saved [~ ~]]
    =.  apps.state  (~(put in apps.state) %cover)
    =^  cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    [cards this]
  ::
      %2
    =/  old-batch=(list pending-forward)
      (turn ~(val by pending.saved) |=(op=old-pending [next.op cell.op]))
    =.  state
      [%3 next-id.saved apps.saved queues.saved relays.saved ~ recent-routes.saved [old-batch ~]]
    =.  apps.state  (~(put in apps.state) %cover)
    =^  cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    [cards this]
  ::
      %3
    =.  state  saved
    =.  apps.state  (~(put in apps.state) %cover)
    =^  cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    [cards this]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %skein-admin
    ?>  =(our src):bowl
    =/  act  !<(admin-action vase)
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
      :-  [(relay-card [%relay-added descriptor.act])]~
      this
    ::
        %drop-relay
      =.  relays.state  (~(del by relays.state) relay.act)
      :-  [(relay-card [%relay-removed relay.act])]~
      this
    ::
        %clear-seen
      =.  seen.state  ~
      :-  [(relay-card [%replay-cleared ~])]~
      this
    ==
  ::
      %skein-send
    ?>  =(our src):bowl
    =/  req  !<(send-request vase)
    ?.  (~(has in apps.state) from.req)
      `this
    =/  resolved-route=(unit route)
      ?~  route.opts.req
        ?:(=(ship.to.req our.bowl) ~ (select-route to.req relays.state now.bowl eny.bowl))
      `(hydrate-route u.route.opts.req relays.state)
    =/  resolved-opts=send-options  [resolved-route reply-blocks.opts.req ttl.opts.req]
    =/  env=envelope
      [next-id.state (local-endpoint from.req our.bowl) to.req now.bowl payload.req resolved-opts]
    =.  next-id.state  +(next-id.state)
    ::  local loopback
    ?:  ?&(=(ship.to.req our.bowl) ?=(~ resolved-route))
      =^  cards  queues.state  (deliver-envelope env apps.state queues.state)
      [cards this]
    ::  no route
    ?~  resolved-route
      :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'no-route'])]~
      this
    =/  full-route=(list ship)  (route-ships to.req resolved-opts)
    ?~  full-route
      :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'no-route'])]~
      this
    =/  cell-id=@uv  (cell-id-for id.env origin.env target.env sent-at.env)
    =/  body-key=(unit relay-key)  (payload-key-for cell-id to.req u.resolved-route)
    =/  body=payload-box  (seal-payload body-key payload.req)
    =/  header=header-box
      (build-header full-route hops.u.resolved-route cell-id body-key)
    =/  cell=relay-cell
      :*  cell-id  id.env  origin.env  target.env  sent-at.env
          t.full-route  header  body  resolved-opts
          (expiry-for opts.req now.bowl)
      ==
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
      :-  [(relay-card [%dropped cell-id.cell 'expired'])]~
      this
    ?:  (seen-step cell seen.state)
      :-  [(relay-card [%dropped cell-id.cell 'replay'])]~
      this
    =.  seen.state  (remember-step cell seen.state now.bowl)
    =.  seen.state  (prune-seen seen.state now.bowl)
    ::  try to open layered header
    =/  layer=(unit header-layer)
      (open-local-header cell relays.state our.bowl now.bowl)
    ?:  ?&(!=(header.cell 0x0) ?=(~ layer))
      :-  [(relay-card [%dropped cell-id.cell 'header-unopenable'])]~
      this
    ?:  ?&(?=(^ layer) !=(remaining.cell remaining.u.layer))
      :-  [(relay-card [%dropped cell-id.cell 'header-mismatch'])]~
      this
    =/  current=relay-cell
      ?~(layer cell (advance-cell cell u.layer))
    =/  base=(list card)
      [(relay-card [%received cell-id.cell src.bowl])]~
    ::  final destination
    ?:  ?&(=(ship.target.current our.bowl) ?=(~ remaining.current))
      =/  payload=(unit *)
        ?~  layer
          (payload-from-cell current ~)
        (payload-from-cell current body-key.u.layer)
      ?~  payload
        [(weld base [(relay-card [%dropped cell-id.current 'payload-unopenable'])]~) this]
      =^  cards  queues.state
        (deliver-cell current u.payload apps.state queues.state)
      [(weld base cards) this]
    ::  forward to next hop
    =/  target=(unit [next=ship cell=relay-cell])
      (forward-target current)
    ?~  target
      [(weld base [(relay-card [%dropped cell-id.current 'route-exhausted'])]~) this]
    =/  hop-delay=(unit @dr)
      ?~(layer ~ delay.u.layer)
    =^  cards  mix.state
      (dispatch-cell next.u.target cell.u.target hop-delay mix.state now.bowl)
    [(weld base cards) this]
  ==
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
      [%app * %inbox ~]
    =/  app=app-id  i.t.path
    ?.  (~(has in apps.state) app)
      `this
    [(backlog-cards app (flop (queue-for app queues.state))) this]
  ==
::
++  on-leave  on-leave:def
++  on-agent  on-agent:def
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign-arvo)
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
      ?.  ?&  (gth ~(wyt by relays.state) 0)
              (lth (mod (mug eny.bowl) cover-chance) 1)
          ==
        ~
      [(cover-send-card our.bowl)]~
    ::  re-arm epoch timer
    =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    [(zing ~[flush-cards cover-cards timer-cards]) this]
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
