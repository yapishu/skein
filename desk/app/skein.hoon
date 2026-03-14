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
++  default-seeds  (sy ~[~sovsef-risfex-sitful-hatred])
++  adaptive-threshold-1  3   ::  3+ relays -> min 1 hop
++  adaptive-threshold-2  6   ::  6+ relays -> min 2 hops
++  min-body-size  8.192      ::  pad body to 8KB minimum (bytes)
++  min-header-size  2.048    ::  pad header to 2KB minimum (bytes)
++  max-retries  3            ::  max first-hop delivery retries
++  retry-base  ~s10          ::  base backoff for retries
++  trusted-weight-boost  5   ::  weight multiplier for trusted relays
++  cover-quiet-threshold  ~m2  ::  send extra cover if no real sends for this long
::
::  internal types
::
+$  pending-forward
  $:  next=ship
      cell=relay-cell
  ==
::
+$  retry-entry
  $:  cell=relay-cell
      target=ship
      attempts=@ud
      next-try=@da
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
      queues=*
      relays=*
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
      queues=*
      relays=*
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
      queues=*
      relays=*
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-key=relay-key
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
  ==
::
::
::  state-15: multiple bootstrap seeds, adaptive hops, relay health
::
+$  state-15
  $:  %15
      next-id=@ud
      apps=(set app-id)
      queues=*
      relays=*
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-key=relay-key
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
      seeds=(set @p)
      adaptive-hops=?
      health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
  ==
::
::
::  state-16: reply-token storage for reply blocks
::
+$  state-16
  $:  %16
      next-id=@ud
      apps=(set app-id)
      queues=*
      relays=*
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-key=relay-key
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
      seeds=(set @p)
      adaptive-hops=?
      health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
      reply-tokens=(map @uv reply-token)
  ==
::
::
::  state-17: discovery trust, reliability, cover refinement
::
+$  state-17
  $:  %17
      next-id=@ud
      apps=(set app-id)
      queues=*                                ::  type changed (reply-block)
      relays=*                                ::  type changed (relay-descriptor)
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-key=relay-key
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
      seeds=(set @p)
      adaptive-hops=?
      health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
      reply-tokens=(map @uv reply-token)
      trusted=(set relay-id)
      descriptor-sources=*                    ::  type changed (relay-id refs relay-descriptor)
      retries=*                               ::  protocol-incompatible
      last-real-send=@da
  ==
::
::  state-18: asymmetric crypto, per-hop cell-id, body onion
::
+$  state-18
  $:  %18
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-seed=@ux                            ::  crub private seed (never published)
      our-pub=@ux                             ::  crub public key (published in descriptor)
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
      seeds=(set @p)
      adaptive-hops=?
      health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
      trusted=(set relay-id)
      descriptor-sources=(map relay-id ship)
      retries=(list retry-entry)
      last-real-send=@da
  ==
::
+$  state-19
  $:  %19
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-seed=@ux                            ::  crub private seed (never published)
      our-pub=@ux                             ::  crub public key (published in descriptor)
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
      seeds=(set @p)
      adaptive-hops=?
      health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
      trusted=(set relay-id)
      descriptor-sources=(map relay-id ship)
      retries=(list retry-entry)
      last-real-send=@da
      minted-contacts=(map app-id @ux)
  ==
::
+$  current-state  state-19
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
  =/  cid-seg=@ta  (scot %uv cell-id.cell)
  =/  who-seg=@ta  (scot %p who)
  [%pass /cell/[cid-seg]/[who-seg] %agent [who %skein] %poke %skein-cell !>(cell)]
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
  |=  [our=ship our-pub=@ux]
  ^-  relay-descriptor
  =/  rid=relay-id  (scot %p our)
  [rid our our-pub 1 ~ ~]
::
++  known-ships
  |=  relays=(map relay-id relay-descriptor)
  ^-  (set ship)
  %-  ~(rep by relays)
  |=  [[rid=relay-id rd=relay-descriptor] out=(set ship)]
  (~(put in out) ship.rd)
::
++  merge-relays
  |=  $:  ours=ship
          pool=(list relay-descriptor)
          relays=(map relay-id relay-descriptor)
          sources=(map relay-id ship)
          source=ship
          now=@da
      ==
  ^-  [(list relay-descriptor) (map relay-id relay-descriptor) (map relay-id ship)]
  ::  returns [new-descriptors updated-map updated-sources]
  ::  caps at max-relays, deduplicates by ship, skips self, enforces expiry
  =/  ships=(set ship)  (known-ships relays)
  =/  new=(list relay-descriptor)  ~
  |-
  ?~  pool  [(flop new) relays sources]
  ?:  (gte ~(wyt by relays) max-relays)
    [(flop new) relays sources]
  ?:  =(ship.i.pool ours)
    $(pool t.pool)
  ::  reject expired descriptors
  ?:  ?&(?=(^ expiry.i.pool) (gth now u.expiry.i.pool))
    $(pool t.pool)
  ?:  (~(has in ships) ship.i.pool)
    $(pool t.pool)
  =.  relays   (~(put by relays) relay.i.pool i.pool)
  =.  sources  (~(put by sources) relay.i.pool source)
  =.  ships    (~(put in ships) ship.i.pool)
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
  [ship.hop relay.hop pub.hop delay]
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
++  relay-score
  |=  $:  rd=relay-descriptor
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          trusted=(set relay-id)
      ==
  ^-  @ud
  =/  base=@ud  (max 1 weight.rd)
  ::  boost trusted relays
  =.  base  ?:((~(has in trusted) relay.rd) (mul base trusted-weight-boost) base)
  =/  hp=(unit [success=@ud failure=@ud last-fail=(unit @da)])
    (~(get by health) relay.rd)
  ?~  hp  base
  =/  total=@ud  (add success.u.hp failure.u.hp)
  ?:  =(total 0)  base
  (max 1 (div (mul success.u.hp base) total))
::
++  effective-min-hops
  |=  [adaptive=? manual=@ud relay-count=@ud]
  ^-  @ud
  ?.  adaptive  manual
  ?:  (gte relay-count adaptive-threshold-2)  2
  ?:  (gte relay-count adaptive-threshold-1)  1
  0
::
++  shuffle-relays
  |=  $:  eny=@
          relays=(list relay-descriptor)
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          trusted=(set relay-id)
      ==
  ^-  (list relay-descriptor)
  %+  sort  relays
  |=  [a=relay-descriptor b=relay-descriptor]
  ::  weight-biased random: score * 1000 + random 0-999
  =/  sa=@ud
    (add (mul (relay-score a health trusted) 1.000) (mod (mug (sham [eny relay.a])) 1.000))
  =/  sb=@ud
    (add (mul (relay-score b health trusted) 1.000) (mod (mug (sham [eny relay.b])) 1.000))
  (gth sa sb)
::
++  unique-hops
  |=  [relays=(list relay-descriptor) count=@ud exclude=(set ship)]
  ^-  (list route-hop)
  ?:  =(count 0)  ~
  ?~  relays  ~
  ?:  (~(has in exclude) ship.i.relays)
    $(relays t.relays)
  =/  hop=route-hop
    [ship.i.relays relay.i.relays pub.i.relays default-delay.i.relays]
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
  `[ship.i.descriptors relay.i.descriptors pub.i.descriptors default-delay.i.descriptors]
::
++  select-route
  |=  $:  our=ship
          target=endpoint
          relays=(map relay-id relay-descriptor)
          now=@da
          eny=@
          min-hops=@ud
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          recent=(list route-log)
          trusted=(set relay-id)
      ==
  ^-  (unit route)
  =/  candidates=(list relay-descriptor)
    (shuffle-relays eny (eligible-relays our relays ship.target now) health trusted)
  =/  final-hop=(unit route-hop)  (target-route-hop relays ship.target now)
  ::  exclude target + ships from most recent route to same target
  =/  prev-hops=(list ship)
    =/  prev=(list route-log)
      (skim recent |=(rl=route-log =(target.rl target)))
    ?~(prev ~ hops.i.prev)
  =/  exclude=(set ship)
    =/  base=(set ship)
      ?~(final-hop ~ (sy ~[ship.target]))
    (~(uni in base) (sy prev-hops))
  =/  mids=(list route-hop)  (unique-hops candidates min-hops exclude)
  ::  fall back without route-reuse exclusion if not enough hops
  =/  mids=(list route-hop)
    ?:  (gte (lent mids) min-hops)  mids
    =/  base-exclude=(set ship)
      ?~(final-hop ~ (sy ~[ship.target]))
    (unique-hops candidates min-hops base-exclude)
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
::  pad atom to at least min-size bytes by adding high bytes
::  cue will ignore the high-byte padding when decoding jammed data
::
++  pad-atom
  |=  [data=@ min-size=@ud eny=@]
  ^-  @
  =/  current=@ud  (met 3 data)
  ?:  (gte current min-size)  data
  =/  pad-size=@ud  (sub min-size current)
  =/  padding=@  (end [3 pad-size] (shaz (mix eny data)))
  ::  ensure padding has at least one nonzero high byte
  =/  padding=@  ?:(=(0 padding) 1 padding)
  (add data (lsh [3 current] padding))
::
::  build reply block: a pre-built encrypted route back to us
::
++  build-reply-block
  |=  $:  our=ship
          relays=(map relay-id relay-descriptor)
          our-seed=@ux
          our-pub=@ux
          now=@da
          eny=@
          min-hops=@ud
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          recent=(list route-log)
          trusted=(set relay-id)
      ==
  ^-  (unit [=reply-block token=reply-token])
  ::  select intermediate hops (route ending at us)
  =/  candidates=(list relay-descriptor)
    (shuffle-relays eny (eligible-relays our relays our now) health trusted)
  =/  mids=(list route-hop)  (unique-hops candidates min-hops ~)
  ::  add self as final destination hop
  =/  self-hop=route-hop  [our (scot %p our) our-pub ~]
  =/  hops=(list route-hop)  (snoc mids self-hop)
  ?~  hops  ~
  ::  generate reply token and derive body key
  =/  token=reply-token  `@ux`(shaz (jam [%reply-token eny now]))
  =/  body-key=relay-key  (end [3 32] (shaz (jam [%reply-body token])))
  ::  build onion headers for the return route
  =/  built  (build-header hops body-key eny)
  ?~  built  ~
  =/  first=ship  ship.i.hops
  ::  store rngs in application order (reversed) so replier can use directly
  `[[token first header.u.built (flop rngs.u.built) (some (add now ~d1))] token]
::
::  mint a contact-bundle: jam([%contact-v1 endpoint reply-block])
::
++  mint-contact-bundle
  |=  $:  app=app-id
          our=ship
          relays=(map relay-id relay-descriptor)
          our-seed=@ux
          our-pub=@ux
          now=@da
          eny=@
          min-hops=@ud
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          recent=(list route-log)
          trusted=(set relay-id)
      ==
  ^-  (unit @ux)
  =/  rb-result
    %:  build-reply-block
      our  relays  our-seed  our-pub  now  eny
      min-hops  health  recent  trusted
    ==
  ?~  rb-result  ~
  =/  ep=endpoint  [our app]
  =/  rb=reply-block  reply-block.u.rb-result
  ``@ux`(jam [%contact-v1 ep rb])
::
::  crypto helpers — asymmetric (NaCl box via crub)
::
++  seal-to-pub
  |=  [data=@ their-pub=@ eny=@]
  ^-  (unit @ux)
  ::  ephemeral X25519 DH + symmetric encryption
  =/  eph-seed=@ux  (end [3 32] (shaz (jam [%skein-eph-seal eny data])))
  =/  eph-pub=@ux   `@ux`(puck:ed:crypto eph-seed)
  =/  result
    %-  mule  |.
    =/  shared=@ux    (shar:ed:crypto their-pub eph-seed)
    =/  sym-key=@ux   (end [3 32] (shaz shared))
    =/  sealed=@ux    (en:crub:crypto sym-key data)
    `@ux`(jam [eph-pub sealed])
  ?:(?=(%& -.result) `p.result ~)
::
++  open-from-sealed
  |=  [box=@ux our-seed=@ux]
  ^-  (unit @)
  ?:  (gth (met 3 box) 1.024)  ~
  =/  result
    %-  mule  |.
    =/  raw  (cue box)
    ?@  raw  !!
    ?.  ?=(@ -.raw)  !!
    ?.  ?=(@ +.raw)  !!
    ?.  ?&((lte (met 3 -.raw) 32) (gte (met 3 -.raw) 31))  !!
    =/  shared=@ux  (shar:ed:crypto -.raw our-seed)
    =/  sym-key=@ux  (end [3 32] (shaz shared))
    (need (de:crub:crypto sym-key +.raw))
  ?:(?=(%& -.result) `p.result ~)
::
++  onion-wrap-body
  |=  [body=payload-box rngs=(list @ux)]
  ^-  payload-box
  ?~  rngs  body
  $(body `@ux`(en:crub:crypto i.rngs body), rngs t.rngs)
::
++  onion-peel-body
  |=  [body=payload-box rng=@ux]
  ^-  (unit payload-box)
  (de:crub:crypto rng body)
::
++  open-local-header
  |=  [cell=relay-cell our-seed=@ux]
  ^-  (unit header-layer)
  ?:  =(header.cell 0x0)  ~
  =/  raw  (open-from-sealed header.cell our-seed)
  ?~  raw  ~
  =/  rez  (mule |.((header-layer (cue u.raw))))
  ?:  ?=(%| -.rez)  ~
  `p.rez
::
::
::  payload helpers
::
++  seal-body
  |=  [body-key=relay-key env=envelope eny=@]
  ^-  payload-box
  =/  jammed=@  (jam [id.env origin.env target.env sent-at.env payload.env opts.env])
  (en:crub:crypto body-key jammed)
::
++  open-body
  |=  [body-key=relay-key box=payload-box]
  ^-  (unit envelope)
  =/  raw  (de:crub:crypto body-key box)
  ?~  raw  ~
  =/  val  (mule |.((cue u.raw)))
  ?:  ?=(%| -.val)  ~
  =/  rez  (mule |.((envelope p.val)))
  ?:  ?=(%| -.rez)  ~
  `p.rez
::
::  cell construction
::
++  build-header
  |=  [hops=(list route-hop) body-key=relay-key eny=@]
  ^-  (unit [header=header-box rngs=(list @ux)])
  ?~  hops  ~
  =/  n=@ud  (lent hops)
  ::  generate N rngs in hop order (one per hop for body onion)
  =/  rngs=(list @ux)
    =|  i=@ud
    =|  acc=(list @ux)
    |-
    ?:  =(i n)  (flop acc)
    $(i +(i), acc [(end [3 32] (shaz (jam [%skein-rng eny i]))) acc])
  ::  build from inside out
  =/  rev=(list route-hop)  (flop hops)
  =/  rev-rngs=(list @ux)  (flop rngs)
  ?~  rev  ~
  ?~  rev-rngs  ~
  ::  final hop layer: next=~, next-cell-id=~, include body-key and rng
  =/  final-layer=header-layer
    [next=~ next-cell-id=~ inner=~ body-key=`body-key rng=`i.rev-rngs delay=delay.i.rev]
  =/  sealed=(unit @ux)
    (seal-to-pub (jam final-layer) pub.i.rev eny)
  ?~  sealed  ~
  =/  acc=header-box  u.sealed
  =/  prev-ship=ship  ship.i.rev
  =/  rest=(list route-hop)  t.rev
  =/  rest-rngs=(list @ux)  t.rev-rngs
  =/  counter=@ud  1
  |-
  ?~  rest  `[acc rngs]
  ?~  rest-rngs  `[acc rngs]
  ::  generate random next-cell-id for forwarding to prev-ship
  =/  cid=@uv  `@uv`(sham [%skein-cid eny counter])
  =/  layer=header-layer
    [`prev-ship `cid `acc ~ `i.rest-rngs delay.i.rest]
  =/  new-eny=@  (shaz (jam [eny counter]))
  =/  new-sealed=(unit @ux)
    (seal-to-pub (jam layer) pub.i.rest new-eny)
  ?~  new-sealed  ~
  %=  $
    acc  u.new-sealed
    prev-ship  ship.i.rest
    rest  t.rest
    rest-rngs  t.rest-rngs
    counter  +(counter)
  ==
::
++  advance-cell
  |=  [cell=relay-cell layer=header-layer new-body=payload-box]
  ^-  relay-cell
  =/  inner=header-box  ?~(inner.layer 0x0 u.inner.layer)
  =/  cid=@uv  ?~(next-cell-id.layer cell-id.cell u.next-cell-id.layer)
  [cid inner new-body expiry.cell]
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
  =/  cid=@uv  (cell-id-for id.env origin.env target.env sent-at.env)
  ::  cover traffic: absorb silently, don't poke external agent
  ?:  =(app.target.env %cover)
    :-  :~  (relay-card [%delivered cid %cover])
            (message-card env)
        ==
    queues
  =/  new-queues  (put-queue app.target.env env queues)
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
  =/  req=send-request  [%cover [%endpoint ship.target %cover] 'cover' [~ ~ ~]]
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
          seeds=(set @p)
          adaptive-hops=?
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          trusted=(set relay-id)
          retries=(list retry-entry)
          minted-contacts=(map app-id @ux)
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
      ['effectiveMinHops' (numb:enjs:format (effective-min-hops adaptive-hops min-hops ~(wyt by relays)))]
      ['seeds' (numb:enjs:format ~(wyt in seeds))]
      ['adaptiveHops' b+adaptive-hops]
      ['healthyRelays' (numb:enjs:format ~(wyt by health))]
      ['trustedRelays' (numb:enjs:format ~(wyt in trusted))]
      ['pendingRetries' (numb:enjs:format (lent retries))]
      ['mintedContacts' (numb:enjs:format ~(wyt by minted-contacts))]
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
      ['hasPub' b+%.y]
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
++  health-json
  |=  health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
  ^-  json
  :-  %a
  %+  turn  ~(tap by health)
  |=  [rid=relay-id h=[success=@ud failure=@ud last-fail=(unit @da)]]
  %-  pairs:enjs:format
  :~  ['relay' s+rid]
      ['success' (numb:enjs:format success.h)]
      ['failure' (numb:enjs:format failure.h)]
      :-  'lastFail'
      ?~  last-fail.h  ~
      (numb:enjs:format (div (sub u.last-fail.h ~1970.1.1) ~s1))
  ==
::
++  trusted-json
  |=  trusted=(set relay-id)
  ^-  json
  a+(turn ~(tap in trusted) |=(rid=relay-id s+rid))
::
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
  =/  seed=@ux  (end [3 32] (shaz (jam [%skein-relay-seed our.bowl eny.bowl now.bowl])))
  =.  our-seed.state  seed
  =.  our-pub.state   `@ux`(puck:ed:crypto seed)
  =.  next-id.state  1
  =.  apps.state     (sy ~[%cover])
  =.  queues.state   ~
  =.  relays.state   ~
  =.  seen.state     ~
  =.  recent-routes.state  ~
  =.  mix.state      [~ ~]
  =.  seeds.state    default-seeds
  =.  adaptive-hops.state  %.y
  =.  health.state   ~
  =.  trusted.state  ~
  =.  descriptor-sources.state  ~
  =.  retries.state  ~
  =.  last-real-send.state  now.bowl
  =.  minted-contacts.state  ~
  =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
  ::  bootstrap: subscribe to seed relays to discover network
  =/  boot-cards=(list card)
    %+  murn  ~(tap in seeds.state)
    |=  s=ship
    ?:  =(s our.bowl)  ~
    `[%pass /relay/sub/(scot %p s) %agent [s %skein] %watch /relay/pool]
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
  ::  generate fresh keypair for all migrations (breaking protocol change)
  =/  seed=@ux  (end [3 32] (shaz (jam [%skein-relay-seed our.bowl eny.bowl now.bowl])))
  =/  new-pub=@ux  `@ux`(puck:ed:crypto seed)
  ::
  ?:  =(-.q.old 19)
    =/  saved  !<(state-19 old)
    =.  state  saved
    finish
  ?:  =(-.q.old 18)
    =/  saved  !<(state-18 old)
    =.  state
      :*  %19
          next-id.saved
          apps.saved
          queues.saved
          relays.saved
          seen.saved
          recent-routes.saved
          mix.saved
          our-seed.saved
          our-pub.saved
          channels.saved
          our-channels.saved
          min-hops.saved
          seeds.saved
          adaptive-hops.saved
          health.saved
          trusted.saved
          descriptor-sources.saved
          retries.saved
          last-real-send.saved
          ~              ::  minted-contacts
      ==
    finish
  ?:  =(-.q.old 17)
    =/  saved  !<(state-17 old)
    =.  state
      :*  %19
          next-id.saved
          apps.saved
          ~              ::  queues cleared (protocol-incompatible)
          ~              ::  relays cleared (protocol-incompatible)
          ~              ::  seen cleared
          recent-routes.saved
          mix.saved
          seed
          new-pub
          channels.saved
          our-channels.saved
          min-hops.saved
          seeds.saved
          adaptive-hops.saved
          health.saved
          trusted.saved
          ~    ::  descriptor-sources cleared
          ~    ::  retries cleared
          last-real-send.saved
          ~    ::  minted-contacts
      ==
    finish
  ?:  =(-.q.old 16)
    =/  saved  !<(state-16 old)
    =.  state
      :*  %19
          next-id.saved
          apps.saved
          ~              ::  queues cleared
          ~              ::  relays cleared
          ~              ::  seen cleared
          recent-routes.saved
          mix.saved
          seed
          new-pub
          channels.saved
          our-channels.saved
          min-hops.saved
          seeds.saved
          adaptive-hops.saved
          health.saved
          ~    ::  trusted
          ~    ::  descriptor-sources
          ~    ::  retries
          now.bowl  ::  last-real-send
          ~    ::  minted-contacts
      ==
    finish
  ?:  =(-.q.old 15)
    =/  saved  !<(state-15 old)
    =.  state
      :*  %19
          next-id.saved
          apps.saved
          ~              ::  queues cleared
          ~              ::  relays cleared
          ~              ::  seen cleared
          recent-routes.saved
          mix.saved
          seed
          new-pub
          channels.saved
          our-channels.saved
          min-hops.saved
          seeds.saved
          adaptive-hops.saved
          health.saved
          ~    ::  trusted
          ~    ::  descriptor-sources
          ~    ::  retries
          now.bowl  ::  last-real-send
          ~    ::  minted-contacts
      ==
    finish
  ?:  =(-.q.old 14)
    =/  saved  !<(state-14 old)
    =.  state
      :*  %19
          next-id.saved
          apps.saved
          ~              ::  queues cleared
          ~              ::  relays cleared
          ~              ::  seen cleared
          recent-routes.saved
          mix.saved
          seed
          new-pub
          channels.saved
          our-channels.saved
          min-hops.saved
          default-seeds
          %.y
          ~    ::  health
          ~    ::  trusted
          ~    ::  descriptor-sources
          ~    ::  retries
          now.bowl  ::  last-real-send
          ~    ::  minted-contacts
      ==
    finish
  ?:  =(-.q.old 13)
    =/  saved  !<(state-13 old)
    =.  state
      :*  %19
          next-id.saved
          apps.saved
          ~              ::  queues cleared
          ~              ::  relays cleared
          ~              ::  seen cleared
          recent-routes.saved
          mix.saved
          seed
          new-pub
          channels.saved
          our-channels.saved
          default-min-hops
          default-seeds
          %.y
          ~    ::  health
          ~    ::  trusted
          ~    ::  descriptor-sources
          ~    ::  retries
          now.bowl  ::  last-real-send
          ~    ::  minted-contacts
      ==
    finish
  ?:  =(-.q.old 12)
    =/  saved  !<(state-12 old)
    =.  state
      :*  %19
          next-id.saved
          apps.saved
          ~              ::  queues cleared
          ~              ::  relays cleared
          ~              ::  seen cleared
          recent-routes.saved
          mix.saved
          seed
          new-pub
          ~    ::  channels
          ~    ::  our-channels
          default-min-hops
          default-seeds
          %.y
          ~    ::  health
          ~    ::  trusted
          ~    ::  descriptor-sources
          ~    ::  retries
          now.bowl  ::  last-real-send
          ~    ::  minted-contacts
      ==
    finish
  ::  incompatible older state — fresh start
  =.  state  [%19 1 (sy ~[%cover]) ~ ~ ~ ~ [~ ~] seed new-pub ~ ~ default-min-hops default-seeds %.y ~ ~ ~ ~ now.bowl ~]
  finish
  ::
  ++  finish
    =.  apps.state  (~(put in apps.state) %cover)
    ::  remove self from relays if present
    =.  relays.state  (~(del by relays.state) (scot %p our.bowl))
    =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    ::  ensure seeds are populated (may be empty from migration)
    =?  seeds.state  =(~ seeds.state)  default-seeds
    ::  ensure keypair is populated and seed is exactly 32 bytes
    =?  our-seed.state  =(0x0 our-seed.state)
      (end [3 32] (shaz (jam [%skein-relay-seed our.bowl eny.bowl now.bowl])))
    =.  our-seed.state  (end [3 32] our-seed.state)
    =.  our-pub.state  `@ux`(puck:ed:crypto our-seed.state)
    ::  clear relays to purge any bad descriptors from pre-truncation inits
    =.  relays.state  ~
    =.  descriptor-sources.state  ~
    ::  bootstrap: subscribe to seed relays to discover network
    =/  boot-cards=(list card)
      %+  murn  ~(tap in seeds.state)
      |=  s=ship
      ?:  =(s our.bowl)  ~
      =/  seg=@ta  (scot %p s)
      ?:  (~(has by wex.bowl) [/relay/sub/[seg] s %skein])  ~
      `[%pass /relay/sub/[seg] %agent [s %skein] %watch /relay/pool]
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
    ?-  -.to.req
        ::
        ::  %endpoint: normal addressed send (existing logic)
        ::
        %endpoint
      =/  ep=endpoint  endpoint.to.req
      =/  eff-hops=@ud
        (effective-min-hops adaptive-hops.state min-hops.state ~(wyt by relays.state))
      =/  resolved-route=(unit route)
        ?~  route.opts.req
          ?.  =(ship.ep our.bowl)
            (select-route our.bowl ep relays.state now.bowl eny.bowl eff-hops health.state recent-routes.state trusted.state)
          ~
        `(hydrate-route u.route.opts.req relays.state)
      =/  resolved-opts=send-options  [resolved-route reply-blocks.opts.req ttl.opts.req]
      =/  env=envelope
        [next-id.state (local-endpoint from.req our.bowl) ep now.bowl payload.req resolved-opts]
      =.  next-id.state  +(next-id.state)
      ::  local loopback
      ?:  ?&(=(ship.ep our.bowl) ?=(~ resolved-route))
        ~&  [%skein-send %loopback from.req app.ep]
        =^  cards  queues.state  (deliver-envelope our.bowl env apps.state queues.state)
        [cards this]
      ::  no route
      ?~  resolved-route
        ~&  [%skein-send %no-route from.req (scot %p ship.ep) app.ep]
        :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'no-route'])]~
        this
      =/  full-route=(list ship)  (route-ships ep resolved-opts)
      =/  actual-hops=@ud  (lent hops.u.resolved-route)
      =/  intermediate=@ud  ?:(=(actual-hops 0) 0 (dec actual-hops))
      ~&  [%skein-send %routing from.req (scot %p ship.ep) %via actual-hops %hops]
      ~?  (lth intermediate eff-hops)  [%skein-send %degraded-route %wanted eff-hops %got intermediate]
      ?~  full-route
        :-  [(relay-card [%dropped (cell-id-for id.env origin.env target.env sent-at.env) 'no-route'])]~
        this
      =/  cell-id=@uv  `@uv`(sham [eny.bowl now.bowl next-id.state])
      =/  body-key=relay-key  (end [3 32] (shaz (jam [%skein-body eny.bowl cell-id])))
      =/  body=payload-box  (seal-body body-key env eny.bowl)
      =/  built  (build-header hops.u.resolved-route body-key eny.bowl)
      ?~  built
        ~&  [%skein-send %header-build-failed from.req]
        :-  [(relay-card [%dropped cell-id 'header-build-failed'])]~
        this
      =/  wrapped-body=payload-box  (onion-wrap-body body (flop rngs.u.built))
      =/  cell=relay-cell
        [cell-id header.u.built wrapped-body (expiry-for opts.req now.bowl)]
      =/  selected=route-log
        [cell-id route-id.u.resolved-route ep (route-ships ep resolved-opts) now.bowl]
      =.  recent-routes.state  (trim-routes [selected recent-routes.state])
      ::  track real sends for adaptive cover traffic
      =?  last-real-send.state  !=(from.req %cover)  now.bowl
      =/  first-hop=(unit route-hop)  (route-head hops.u.resolved-route)
      =/  first-delay=(unit @dr)
        ?~  first-hop  ~
        delay.u.first-hop
      =^  cards  mix.state
        (dispatch-cell i.full-route cell first-delay mix.state now.bowl)
      =/  base-cards=(list card)
        :~  (relay-card [%sent cell-id ep])
            (relay-card [%route-selected cell-id u.resolved-route])
        ==
      [(weld base-cards cards) this]
        ::
        ::  %contact: send via contact-bundle (reply-block-routed)
        ::
        %contact
      =/  cue-result  (mule |.((cue contact-bundle.to.req)))
      ?:  ?=(%| -.cue-result)
        ~&  [%skein-send %contact-cue-failed from.req]
        :-  [(relay-card [%dropped `@uv`0 'contact-cue-failed'])]~
        this
      =/  raw  p.cue-result
      ::  validate structure: [%contact-v1 [ship app] [token first-hop header rngs expiry]]
      =/  parse-result
        %-  mule  |.
        ?>  ?=([%contact-v1 *] raw)
        =/  ep  (endpoint +<.raw)
        =/  rb  (reply-block +>.raw)
        [ep rb]
      ?:  ?=(%| -.parse-result)
        ~&  [%skein-send %contact-parse-failed from.req]
        :-  [(relay-card [%dropped `@uv`0 'contact-parse-failed'])]~
        this
      =/  ep=endpoint  -.p.parse-result
      =/  rb=reply-block  +.p.parse-result
      ::  build envelope addressed to the real endpoint
      =/  resolved-opts=send-options  [~ reply-blocks.opts.req ttl.opts.req]
      =/  env=envelope
        [next-id.state (local-endpoint from.req our.bowl) ep now.bowl payload.req resolved-opts]
      =.  next-id.state  +(next-id.state)
      ::  derive body key from reply-block token
      =/  body-key=relay-key  (end [3 32] (shaz (jam [%reply-body token.rb])))
      =/  body=payload-box  (seal-body body-key env eny.bowl)
      ::  wrap body with reply-block rngs (already in application order)
      =/  wrapped-body=payload-box  (onion-wrap-body body rngs.rb)
      ::  build cell using the reply-block header
      =/  cell-id=@uv  `@uv`(sham [eny.bowl now.bowl next-id.state])
      =/  cell=relay-cell
        [cell-id header.rb wrapped-body expiry.rb]
      ::  track real sends for adaptive cover traffic
      =?  last-real-send.state  !=(from.req %cover)  now.bowl
      =/  selected=route-log
        [cell-id `@uv`0 ep ~[first-hop.rb] now.bowl]
      =.  recent-routes.state  (trim-routes [selected recent-routes.state])
      =^  cards  mix.state
        (dispatch-cell first-hop.rb cell ~ mix.state now.bowl)
      =/  base-cards=(list card)
        :~  (relay-card [%sent cell-id ep])
        ==
      [(weld base-cards cards) this]
    ==
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
      (open-local-header cell our-seed.state)
    ?~  layer
      :_  this
      [(relay-card [%dropped cell-id.cell 'undecryptable'])]~
    =/  base=(list card)
      [(relay-card [%received cell-id.cell src.bowl])]~
    ::  peel body onion layer for this hop
    ?~  rng.u.layer
      [(weld base [(relay-card [%dropped cell-id.cell 'no-rng'])]~) this]
    =/  peeled=(unit payload-box)  (onion-peel-body body.cell u.rng.u.layer)
    ?~  peeled
      [(weld base [(relay-card [%dropped cell-id.cell 'body-peel-failed'])]~) this]
    ::  check if we are the final destination
    ?~  next.u.layer
      ::  final destination — decrypt body
      ?~  body-key.u.layer
        [(weld base [(relay-card [%dropped cell-id.cell 'no-body-key'])]~) this]
      =/  env=(unit envelope)
        (open-body u.body-key.u.layer u.peeled)
      ?~  env
        [(weld base [(relay-card [%dropped cell-id.cell 'body-unopenable'])]~) this]
      ?.  =(ship.target.u.env our.bowl)
        [(weld base [(relay-card [%dropped cell-id.cell 'wrong-target'])]~) this]
      =^  cards  queues.state
        (deliver-envelope our.bowl u.env apps.state queues.state)
      [(weld base cards) this]
    ::  forward to next hop — peel body, reassign cell-id
    =/  next-cell=relay-cell  (advance-cell cell u.layer u.peeled)
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
      (give-json-response eyre-id (stats-json our.bowl apps.state relays.state seen.state recent-routes.state mix.state channels.state our-channels.state min-hops.state seeds.state adaptive-hops.state health.state trusted.state retries.state minted-contacts.state))
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
    ::
        [%health ~]
      :_  this
      (give-json-response eyre-id (health-json health.state))
    ::
        [%trusted ~]
      :_  this
      (give-json-response eyre-id (trusted-json trusted.state))
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
      ::  subscribe to the ship to discover its pub and relays
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
    ::
        %'add-seed'
      =/  ship=@p
        ((ot:dejs:format ~[['ship' (se:dejs:format %p)]]) jon)
      `[%add-seed ship]
    ::
        %'drop-seed'
      =/  ship=@p
        ((ot:dejs:format ~[['ship' (se:dejs:format %p)]]) jon)
      `[%drop-seed ship]
    ::
        %'set-adaptive-hops'
      =/  on=?
        ((ot:dejs:format ~[['on' bo:dejs:format]]) jon)
      `[%set-adaptive-hops on]
    ::
        %'build-reply-block'
      `[%build-reply-block ~]
    ::
        %'mint-contact'
      =/  app=app-id
        ((ot:dejs:format ~[['app' so:dejs:format]]) jon)
      `[%mint-contact app]
    ::
        %'trust-relay'
      =/  relay=relay-id
        ((ot:dejs:format ~[['relay' so:dejs:format]]) jon)
      `[%trust-relay relay]
    ::
        %'untrust-relay'
      =/  relay=relay-id
        ((ot:dejs:format ~[['relay' so:dejs:format]]) jon)
      `[%untrust-relay relay]
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
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state)
      :-  :~  (relay-card [%relay-added descriptor.act])
              (pool-fact-card [our-rd (relays-list relays.state)])
          ==
      this
    ::
        %drop-relay
      =.  relays.state  (~(del by relays.state) relay.act)
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state)
      :-  :~  (relay-card [%relay-removed relay.act])
              (pool-fact-card [our-rd (relays-list relays.state)])
          ==
      this
    ::
        %discover-relay
      ::  subscribe to a ship to discover its pub and relay pool
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
    ::
        %add-seed
      =.  seeds.state  (~(put in seeds.state) ship.act)
      ::  try subscribing to the new seed
      =/  sub-cards=(list card)
        ?:  =(ship.act our.bowl)  ~
        ?:  (~(has in (known-ships relays.state)) ship.act)  ~
        =/  seg=@ta  (scot %p ship.act)
        ?:  (~(has by wex.bowl) [/relay/sub/[seg] ship.act %skein])  ~
        :~  [%pass /relay/sub/[seg] %agent [ship.act %skein] %watch /relay/pool]
        ==
      ~&  [%skein %seed-added ship.act]
      :_  this
      [(relay-card [%seed-added ship.act]) sub-cards]
    ::
        %drop-seed
      =.  seeds.state  (~(del in seeds.state) ship.act)
      ~&  [%skein %seed-removed ship.act]
      :-  [(relay-card [%seed-removed ship.act])]~
      this
    ::
        %set-adaptive-hops
      =.  adaptive-hops.state  on.act
      ~&  [%skein %adaptive-hops-set on.act]
      `this
    ::
        %build-reply-block
      =/  eff-hops=@ud
        (effective-min-hops adaptive-hops.state min-hops.state ~(wyt by relays.state))
      =/  result
        (build-reply-block our.bowl relays.state our-seed.state our-pub.state now.bowl eny.bowl eff-hops health.state recent-routes.state trusted.state)
      ?~  result
        ~&  [%skein %reply-block-build-failed %insufficient-relays]
        `this
      ~&  [%skein %reply-block-built token.reply-block.u.result]
      :-  [(relay-card [%reply-block-built reply-block.u.result])]~
      this
    ::
        %mint-contact
      =/  eff-hops=@ud
        (effective-min-hops adaptive-hops.state min-hops.state ~(wyt by relays.state))
      =/  result
        %:  mint-contact-bundle
          app.act  our.bowl  relays.state  our-seed.state  our-pub.state
          now.bowl  eny.bowl  eff-hops  health.state
          recent-routes.state  trusted.state
        ==
      ?~  result
        ~&  [%skein %mint-contact-failed app.act %insufficient-relays]
        `this
      =.  minted-contacts.state  (~(put by minted-contacts.state) app.act u.result)
      ~&  [%skein %contact-minted app.act]
      :-  [(relay-card [%contact-minted app.act])]~
      this
    ::
        %trust-relay
      =.  trusted.state  (~(put in trusted.state) relay.act)
      ~&  [%skein %relay-trusted relay.act]
      :-  [(relay-card [%relay-trusted relay.act])]~
      this
    ::
        %untrust-relay
      =.  trusted.state  (~(del in trusted.state) relay.act)
      ~&  [%skein %relay-untrusted relay.act]
      :-  [(relay-card [%relay-untrusted relay.act])]~
      this
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
  ::
      [%x %reply-block ~]
    ::  build a fresh reply block (informational; use %build-reply-block poke for tracked blocks)
    =/  eff-hops=@ud
      (effective-min-hops adaptive-hops.state min-hops.state ~(wyt by relays.state))
    =/  result
      (build-reply-block our.bowl relays.state our-seed.state our-pub.state now.bowl eny.bowl eff-hops health.state recent-routes.state trusted.state)
    ?~  result  [~ ~]
    ``noun+!>(reply-block.u.result)
  ::
      [%x %health ~]
    ``noun+!>(health.state)
  ::
      [%x %trusted ~]
    ``noun+!>(trusted.state)
  ::
      [%x %seeds ~]
    ``noun+!>(seeds.state)
  ::
      [%x %contact @ ~]
    =/  app=app-id  i.t.t.path
    =/  bundle  (~(get by minted-contacts.state) app)
    ?~  bundle  [~ ~]
    ``noun+!>(u.bundle)
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
    ::  send our pool including our own descriptor so subscriber gets our pub
    =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state)
    =/  full-pool=(list relay-descriptor)  [our-rd (relays-list relays.state)]
    ::  subscribe back to learn their pub (if not already known)
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
      =/  source=ship  (slav %p i.t.t.wire)
      =/  [new-rds=(list relay-descriptor) new-relays=(map relay-id relay-descriptor) new-sources=(map relay-id ship)]
        (merge-relays our.bowl pool relays.state descriptor-sources.state source now.bowl)
      ?~  new-rds  `this
      ::  we learned new relays -- update state, notify subscribers, subscribe to new ones
      =.  relays.state  new-relays
      =.  descriptor-sources.state  new-sources
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
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state)
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
      [%cell @ @ ~]
    ::  track relay health from cell delivery acks
    =/  who-seg=@ta  i.t.t.wire
    =/  relay-ship=ship  (slav %p who-seg)
    ?+  -.sign  `this
        %poke-ack
      =/  rid=relay-id  (scot %p relay-ship)
      =/  cur=[success=@ud failure=@ud last-fail=(unit @da)]
        (~(gut by health.state) rid [0 0 ~])
      =.  health.state
        ?~  p.sign
          (~(put by health.state) rid [+(success.cur) failure.cur last-fail.cur])
        (~(put by health.state) rid [success.cur +(failure.cur) `now.bowl])
      `this
    ==
  ::
      [%cell @ ~]
    ::  legacy cell ack (pre-state-15 wire format), ignore
    `this
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
    ::  prune expired relay descriptors
    =/  expired-rids=(list relay-id)
      %+  murn  (relays-list relays.state)
      |=  rd=relay-descriptor
      ?~  expiry.rd  ~
      ?.  (gth now.bowl u.expiry.rd)  ~
      `relay.rd
    =/  prune-cards=(list card)
      (turn expired-rids |=(rid=relay-id (relay-card [%relay-expired rid])))
    =.  relays.state
      =/  rr  relays.state
      =/  rids  expired-rids
      |-
      ?~  rids  rr
      $(rids t.rids, rr (~(del by rr) i.rids))
    =.  descriptor-sources.state
      =/  ss  descriptor-sources.state
      =/  rids  expired-rids
      |-
      ?~  rids  ss
      $(rids t.rids, ss (~(del by ss) i.rids))
    ::  process retry queue
    =/  due=(list retry-entry)
      (skim retries.state |=(re=retry-entry (lte next-try.re now.bowl)))
    =/  not-due=(list retry-entry)
      (skip retries.state |=(re=retry-entry (lte next-try.re now.bowl)))
    =/  retry-cards=(list card)
      %+  turn  due
      |=  re=retry-entry
      (send-cell-card target.re cell.re)
    ::  re-queue with incremented attempts, drop maxed-out entries
    =/  requeued=(list retry-entry)
      %+  murn  due
      |=  re=retry-entry
      ?:  (gte +(attempts.re) max-retries)  ~
      =/  backoff=@dr  (mul retry-base (bex attempts.re))
      `[cell.re target.re +(attempts.re) (add now.bowl backoff)]
    =.  retries.state  (weld requeued not-due)
    ::  adaptive cover traffic: increase when quiet
    =/  quiet=?  (gth (sub now.bowl last-real-send.state) cover-quiet-threshold)
    =/  cover-cards=(list card)
      ?.  (gth ~(wyt by relays.state) 1)
        ~
      ::  higher cover chance when quiet, normal chance otherwise
      =/  chance=@ud  ?:(quiet 1 cover-chance)
      ?.  (lth (mod (mug eny.bowl) chance) 1)
        ~
      =/  cc  (cover-send-card our.bowl eny.bowl relays.state)
      ?~(cc ~ [u.cc]~)
    ::  re-attempt bootstrap if we have no relays and no pending sub
    =/  bootstrap-cards=(list card)
      ?.  =(~ relays.state)  ~
      %+  murn  ~(tap in seeds.state)
      |=  s=ship
      ?:  =(s our.bowl)  ~
      =/  seg=@ta  (scot %p s)
      ?:  (~(has by wex.bowl) [/relay/sub/[seg] s %skein])  ~
      `[%pass /relay/sub/[seg] %agent [s %skein] %watch /relay/pool]
    ::  re-arm epoch timer
    =^  timer-cards  mix.state  (ensure-epoch-timer mix.state now.bowl)
    [(zing ~[flush-cards prune-cards retry-cards cover-cards bootstrap-cards timer-cards]) this]
  ::
      [%delay *]
    ::  legacy timer from state-2, discard
    [~ this]
  ::
      [%cell *]
    ::  arvo sign on cell wire (behn timer etc), ignore
    [~ this]
  ::
      [%cover ~]
    ::  ack from cover self-poke, ignore
    [~ this]
  ==
++  on-fail   on-fail:def
--
