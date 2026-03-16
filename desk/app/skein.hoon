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
++  usable-source-threshold  2  ::  sources needed before relay becomes %usable
++  max-alternates  2           ::  max alternate routes in route-set
++  default-max-reselects  2   ::  ws2: fresh route selections after alternates exhausted
++  intro-batch-size  4        ::  ws1: entries per introduction bundle
::
::  ws4: profile-aligned delay windows
::
++  profile-delay
  |=  p=cell-profile
  ^-  (unit @dr)
  ?-  p
    %small   `~s5
    %medium  `~s15
    %large   `~s30
  ==
::
::  workstream 3: cell profile dimensions (bytes)
::
++  profile-body-size
  |=  p=cell-profile
  ^-  @ud
  ?-  p
    %small   8.192
    %medium  32.768
    %large   131.072
  ==
::
++  profile-header-size
  |=  p=cell-profile
  ^-  @ud
  ?-  p
    %small   2.048
    %medium  4.096
    %large   8.192
  ==
::
++  auto-profile
  |=  payload-size=@ud
  ^-  cell-profile
  ?:  (lte payload-size 8.192)    %small
  ?:  (lte payload-size 32.768)   %medium
  %large
::
::  internal types
::
+$  pending-forward
  $:  next=ship
      cell=relay-cell
  ==
::
+$  retry-entry
  $:  env=envelope
      body-key=relay-key
      prof=cell-profile
      routes=(list route)      ::  remaining routes to try (head = next)
      attempts=@ud
      next-try=@da
      max-reselects=@ud        ::  ws2: budget for fresh route selections
  ==
::
+$  mix-state
  $:  batch=(list pending-forward)
      timer=(unit @da)
  ==
::
::
+$  state-0
  $:  %0
      next-id=@ud
      apps=(set app-id)
      queues=(map app-id (list envelope))
      relays=(map relay-id relay-descriptor)
      seen=(map @uv @da)
      recent-routes=(list route-log)
      mix=mix-state
      our-seed=@ux
      our-pub=@ux
      channels=(map channel-id (map @p @da))
      our-channels=(map channel-id app-id)
      min-hops=@ud
      seeds=(set @p)
      adaptive-hops=?
      health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
      trusted=(set relay-id)
      relay-metas=(map relay-id relay-meta)
      retries=(list retry-entry)
      last-real-send=@da
      minted-contacts=(map @uv @ux)
      consumed-entries=(map @ux @da)
      profile-counts=[small=@ud medium=@ud large=@ud]
      bundle-progress=(map @ux @ud)
      exhausted-bundles=(set @ux)
      queued-no-route=@ud
      reselected=@ud
      exhausted-reselects=@ud
  ==
::
+$  current-state  state-0
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
  |=  [our=ship our-pub=@ux our-seed=@ux]
  ^-  relay-descriptor
  =/  rid=relay-id  (scot %p our)
  =/  msg=@  (jam [rid our our-pub 1])
  =/  sig=@ux  (sign:ed:crypto msg our-seed)
  [rid our our-pub 1 ~ ~ sig]
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
          metas=(map relay-id relay-meta)
          trusted=(set relay-id)
          source=ship
          now=@da
      ==
  ^-  [(list relay-descriptor) (map relay-id relay-descriptor) (map relay-id relay-meta)]
  ::  returns [new-descriptors updated-map updated-metas]
  ::  caps at max-relays, deduplicates by ship, skips self, enforces expiry
  ::  workstream 1: tracks multiple sources per relay, computes status
  =/  ships=(set ship)  (known-ships relays)
  =/  new=(list relay-descriptor)  ~
  |-
  ?~  pool  [(flop new) relays metas]
  ?:  (gte ~(wyt by relays) max-relays)
    [(flop new) relays metas]
  ?:  =(ship.i.pool ours)
    $(pool t.pool)
  ::  reject expired descriptors
  ?:  ?&(?=(^ expiry.i.pool) (gth now u.expiry.i.pool))
    $(pool t.pool)
  ::  Fix 4: reject unsigned or invalid-signature descriptors
  =/  desc-msg=@  (jam [relay.i.pool ship.i.pool pub.i.pool weight.i.pool])
  ?.  (veri:ed:crypto sig.i.pool desc-msg pub.i.pool)
    ~&  [%skein %merge-relays %bad-sig relay.i.pool]
    $(pool t.pool)
  ::  update existing relay: refresh descriptor (including pubkey) + metadata
  ?:  (~(has in ships) ship.i.pool)
    =/  cur-meta=relay-meta  (gut-relay-meta relay.i.pool metas now)
    =/  new-sources=(set ship)  (~(put in sources.cur-meta) source)
    =/  new-status=relay-status
      (compute-relay-status relay.i.pool new-sources trusted)
    =/  upd=relay-meta
      [new-sources first-seen.cur-meta now new-status family.cur-meta]
    ::  always update descriptor (pubkey may have changed after nuke/rekey)
    =.  relays  (~(put by relays) relay.i.pool i.pool)
    =.  metas   (~(put by metas) relay.i.pool upd)
    $(pool t.pool)
  ::  new relay — initialize metadata
  =/  init-status=relay-status
    (compute-relay-status relay.i.pool (sy ~[source]) trusted)
  =/  meta=relay-meta  [(sy ~[source]) now now init-status ~]
  =.  relays   (~(put by relays) relay.i.pool i.pool)
  =.  metas    (~(put by metas) relay.i.pool meta)
  =.  ships    (~(put in ships) ship.i.pool)
  =.  new  [i.pool new]
  $(pool t.pool)
::
::  workstream 1: compute relay status from source count and trust
::
++  compute-relay-status
  |=  [rid=relay-id sources=(set ship) trusted=(set relay-id)]
  ^-  relay-status
  ?:  (~(has in trusted) rid)  %trusted
  ?:  (gte ~(wyt in sources) usable-source-threshold)  %usable
  %provisional
::
++  gut-relay-meta
  |=  [rid=relay-id metas=(map relay-id relay-meta) now=@da]
  ^-  relay-meta
  =/  existing  (~(get by metas) rid)
  ?~  existing  [~ now now %provisional ~]
  u.existing
::
::  ws3: get relay family from metadata
::
++  relay-family
  |=  [rid=relay-id metas=(map relay-id relay-meta)]
  ^-  (unit @t)
  =/  meta  (~(get by metas) rid)
  ?~  meta  ~
  family.u.meta
::
::  ws3: get families used in a set of relays
::
++  used-families
  |=  [ships=(set ship) relays=(map relay-id relay-descriptor) metas=(map relay-id relay-meta)]
  ^-  (set @t)
  %-  ~(rep by relays)
  |=  [[rid=relay-id rd=relay-descriptor] out=(set @t)]
  ?.  (~(has in ships) ship.rd)  out
  =/  fam  (relay-family relay.rd metas)
  ?~  fam  out
  (~(put in out) u.fam)
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
::  workstream 1: eligible-relays now takes relay-metas and filters by status
::  role: %any = all usable+trusted, %middle = only usable+trusted (no provisional)
::  %entry = provisional allowed (for first-hop fallback)
::
++  eligible-relays
  |=  $:  our=ship
          relays=(map relay-id relay-descriptor)
          metas=(map relay-id relay-meta)
          target=ship
          now=@da
          role=?(%any %middle %entry)
      ==
  ^-  (list relay-descriptor)
  %+  murn  (relays-list relays)
  |=  d=relay-descriptor
  ?:  =(ship.d our)  ~
  ?:  =(ship.d target)  ~
  ?.  (live-relay d now)  ~
  ::  workstream 1: filter by provenance status based on role
  =/  meta=relay-meta  (gut-relay-meta relay.d metas now)
  ?-  role
    %any     `d
    %entry   `d                  ::  provisional OK for entry/first hops
    %middle
      ?:  =(status.meta %provisional)  ~
      `d
  ==
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
::  workstream 1+4: select-route now takes metas, returns route-set
::  builds primary route from usable/trusted middle hops,
::  then builds alternates with different entry relays
::
++  select-route
  |=  $:  our=ship
          target=endpoint
          relays=(map relay-id relay-descriptor)
          metas=(map relay-id relay-meta)
          now=@da
          eny=@
          min-hops=@ud
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          recent=(list route-log)
          trusted=(set relay-id)
      ==
  ^-  (unit route-set)
  ::  workstream 1: use %middle role for middle hops (excludes provisional)
  =/  mid-candidates=(list relay-descriptor)
    (shuffle-relays eny (eligible-relays our relays metas ship.target now %middle) health trusted)
  ::  workstream 1: use %entry role for all candidates (allows provisional as entry)
  =/  all-candidates=(list relay-descriptor)
    (shuffle-relays eny (eligible-relays our relays metas ship.target now %entry) health trusted)
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
  =/  mids=(list route-hop)  (unique-hops mid-candidates min-hops exclude)
  ::  fall back: try without route-reuse exclusion
  =/  mids=(list route-hop)
    ?:  (gte (lent mids) min-hops)  mids
    =/  base-exclude=(set ship)
      ?~(final-hop ~ (sy ~[ship.target]))
    (unique-hops mid-candidates min-hops base-exclude)
  ::  fall back: allow provisional relays as middle hops if not enough usable
  =/  mids=(list route-hop)
    ?:  (gte (lent mids) min-hops)  mids
    =/  base-exclude=(set ship)
      ?~(final-hop ~ (sy ~[ship.target]))
    (unique-hops all-candidates min-hops base-exclude)
  =/  hops=(list route-hop)
    ?~  final-hop  mids
    (snoc mids u.final-hop)
  ?~  hops  ~
  =/  primary=route  [(sham [eny target now]) hops]
  ::  workstream 4: build alternate routes with different entry relays
  =/  primary-entry=(set ship)  (sy ~[ship.i.hops])
  =/  alts=(list route)
    (build-alternates our target relays metas now eny min-hops health trusted final-hop primary-entry)
  `[primary alts]
::
::  workstream 4: build alternate routes with different entry relays
::  ws3: avoid primary route's family, not just its entry ship
::
++  build-alternates
  |=  $:  our=ship
          target=endpoint
          relays=(map relay-id relay-descriptor)
          metas=(map relay-id relay-meta)
          now=@da
          eny=@
          min-hops=@ud
          health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)])
          trusted=(set relay-id)
          final-hop=(unit route-hop)
          used-entries=(set ship)
      ==
  ^-  (list route)
  =/  all-candidates=(list relay-descriptor)
    (shuffle-relays (shaz (jam [eny %alt])) (eligible-relays our relays metas ship.target now %entry) health trusted)
  =/  count=@ud  0
  =/  acc=(list route)  ~
  =/  excluded=(set ship)
    =/  base=(set ship)  ?~(final-hop ~ (sy ~[ship.target]))
    (~(uni in base) used-entries)
  ::  ws3: collect families of excluded entry relays
  =/  excluded-families=(set @t)
    (used-families used-entries relays metas)
  |-
  ?:  (gte count max-alternates)  (flop acc)
  ?~  all-candidates  (flop acc)
  ::  skip candidates already used as entries
  ?:  (~(has in excluded) ship.i.all-candidates)
    $(all-candidates t.all-candidates)
  ::  ws3: skip candidates in same family as primary entry
  =/  cand-fam  (relay-family relay.i.all-candidates metas)
  ?:  ?&(?=(^ cand-fam) (~(has in excluded-families) u.cand-fam))
    $(all-candidates t.all-candidates)
  ::  build route with this candidate as entry
  =/  entry-hop=route-hop
    [ship.i.all-candidates relay.i.all-candidates pub.i.all-candidates default-delay.i.all-candidates]
  =/  mid-exclude=(set ship)  (~(put in excluded) ship.i.all-candidates)
  ::  pick middle hops from usable/trusted relays only
  =/  mid-pool=(list relay-descriptor)
    (shuffle-relays (shaz (jam [eny %alt count])) (eligible-relays our relays metas ship.target now %middle) health trusted)
  =/  mid-count=@ud  ?:((gth min-hops 0) (dec min-hops) 0)
  =/  mid-hops=(list route-hop)  (unique-hops mid-pool mid-count mid-exclude)
  =/  alt-hops=(list route-hop)
    ?~  final-hop  [entry-hop mid-hops]
    [entry-hop (snoc mid-hops u.final-hop)]
  =/  alt-route=route  [(sham [eny target now count]) alt-hops]
  ::  ws3: track family of this alternate's entry too
  =/  new-excluded-families=(set @t)
    ?~  cand-fam  excluded-families
    (~(put in excluded-families) u.cand-fam)
  %=  $
    all-candidates    t.all-candidates
    count             +(count)
    acc               [alt-route acc]
    excluded          (~(put in excluded) ship.i.all-candidates)
    excluded-families  new-excluded-families
  ==
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
::  workstream 3: pad body and header to profile dimensions
::
++  pad-to-profile
  |=  [body=payload-box header=header-box prof=cell-profile eny=@]
  ^-  [body=payload-box header=header-box]
  =/  body-target=@ud  (profile-body-size prof)
  =/  header-target=@ud  (profile-header-size prof)
  :_  (pad-atom header header-target (shaz (jam [eny %header-pad])))
  (pad-atom body body-target (shaz (jam [eny %body-pad])))
::
::  build a complete relay-cell for a given route from envelope + body-key
::  returns ~ if header build fails or route has no hops
::
++  build-cell-for-route
  |=  [env=envelope body-key=relay-key rte=route prof=cell-profile eny=@ now=@da]
  ^-  (unit [cell=relay-cell first-hop=ship])
  ?~  hops.rte  ~
  =/  body=payload-box  (seal-body body-key env eny)
  =/  rngs=(list @ux)  (gen-rngs (lent hops.rte) eny)
  =/  wrapped-body=payload-box  (onion-wrap-body body (flop rngs))
  =/  macs=(list (unit @ux))  (compute-body-macs wrapped-body rngs)
  =/  built  (build-header hops.rte body-key eny macs)
  ?~  built  ~
  =/  padded=[body=payload-box header=header-box]
    (pad-to-profile wrapped-body header.u.built prof eny)
  =/  cell-id=@uv  `@uv`(sham [eny id.env route-id.rte])
  =/  cell=relay-cell
    [cell-id header.padded body.padded (expiry-for opts.env now) prof]
  `[cell ship.i.hops.rte]
::
::  build reply block: a pre-built encrypted route back to us
::
++  build-reply-block
  |=  $:  our=ship
          relays=(map relay-id relay-descriptor)
          metas=(map relay-id relay-meta)
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
    (shuffle-relays eny (eligible-relays our relays metas our now %middle) health trusted)
  =/  mids=(list route-hop)  (unique-hops candidates min-hops ~)
  ::  add self as final destination hop
  =/  self-hop=route-hop  [our (scot %p our) our-pub ~]
  =/  hops=(list route-hop)  (snoc mids self-hop)
  ?~  hops  ~
  ::  generate reply token and derive body key
  =/  token=reply-token  `@ux`(shaz (jam [%reply-token eny now]))
  =/  body-key=relay-key  (end [3 32] (shaz (jam [%reply-body token])))
  ::  build onion headers for the return route (no MAC for reply paths)
  =/  built  (build-header hops body-key eny ~)
  ?~  built  ~
  =/  first=ship  ship.i.hops
  ::  store rngs in application order (reversed) so replier can use directly
  `[[token first header.u.built (flop rngs.u.built) (some (add now ~d1))] token]
::
::  mint a contact-bundle: jam([%contact-v2 app token first-hop header rngs expiry])
::  Fix 1: no endpoint (ship) — destination encoded in reply-block header only
::
++  mint-contact-bundle
  |=  $:  app=app-id
          our=ship
          relays=(map relay-id relay-descriptor)
          metas=(map relay-id relay-meta)
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
  ::  ws1: mint as introduction bundle (batch of entries)
  =/  bundle-id=@ux  `@ux`(shaz (jam [%intro-bundle-id eny now app]))
  =/  count=@ud  0
  =/  entries=(list intro-entry)  ~
  |-
  ?:  =(count intro-batch-size)
    ?~  entries  ~
    =/  ib=intro-bundle  [app bundle-id (flop entries) ~]
    ``@ux`(jam [%intro-v1 app.ib bundle-id.ib entries.ib reply-policy.ib])
  =/  entry-eny=@  (shaz (jam [%intro-entry eny count]))
  =/  rb-result
    %:  build-reply-block
      our  relays  metas  our-seed  our-pub  now  entry-eny
      min-hops  health  recent  trusted
    ==
  ?~  rb-result
    ::  if we can't build even one entry, fall back to contact-v2
    ?~  entries
      =/  rb2
        %:  build-reply-block
          our  relays  metas  our-seed  our-pub  now  eny
          min-hops  health  recent  trusted
        ==
      ?~  rb2  ~
      =/  rb=reply-block  reply-block.u.rb2
      ``@ux`(jam [%contact-v2 app token.rb first-hop.rb header.rb rngs.rb expiry.rb])
    ::  return what we have so far
    =/  ib=intro-bundle  [app bundle-id (flop entries) ~]
    ``@ux`(jam [%intro-v1 app.ib bundle-id.ib entries.ib reply-policy.ib])
  =/  rb=reply-block  reply-block.u.rb-result
  =/  entry=intro-entry  [token.rb first-hop.rb header.rb rngs.rb expiry.rb]
  $(count +(count), entries [entry entries])
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
::  Fix 5: compute per-hop body MACs for integrity checking
::  takes fully wrapped body and rngs in hop order
::  returns MACs in hop order: [mac-for-hop0 mac-for-hop1 ... mac-for-final]
::
++  compute-body-macs
  |=  [wrapped=payload-box rngs=(list @ux)]
  ^-  (list (unit @ux))
  =/  n=@ud  (lent rngs)
  ?:  =(n 0)  ~
  ::  hop 0 sees fully wrapped body
  =/  body=payload-box  wrapped
  =/  hop=@ud  0
  =/  acc=(list (unit @ux))  ~
  |-
  ?:  =(hop n)  (flop acc)
  =/  mac=@ux  (end [3 32] (shaz body))
  ::  peel one layer for next hop
  =/  rng=@ux  (snag hop rngs)
  =/  peeled=(unit payload-box)  (onion-peel-body body rng)
  =.  acc  [`mac acc]
  ?~  peeled
    ::  can't peel further, fill remaining with ~
    $(hop n)
  $(hop +(hop), body u.peeled)
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
++  gen-rngs
  |=  [n=@ud eny=@]
  ^-  (list @ux)
  =|  i=@ud
  =|  acc=(list @ux)
  |-
  ?:  =(i n)  (flop acc)
  $(i +(i), acc [(end [3 32] (shaz (jam [%skein-rng eny i]))) acc])
::
++  build-header
  |=  [hops=(list route-hop) body-key=relay-key eny=@ macs=(list (unit @ux))]
  ^-  (unit [header=header-box rngs=(list @ux)])
  ?~  hops  ~
  =/  n=@ud  (lent hops)
  ::  generate N rngs in hop order (one per hop for body onion)
  =/  rngs=(list @ux)  (gen-rngs n eny)
  ::  Fix 5: per-hop body MACs (hop order). pad if shorter than hops
  =/  mac-list=(list (unit @ux))
    =/  ml=@ud  (lent macs)
    ?:  (gte ml n)  macs
    (weld macs (reap (sub n ml) *(unit @ux)))
  ::  build from inside out
  =/  rev=(list route-hop)  (flop hops)
  =/  rev-rngs=(list @ux)  (flop rngs)
  =/  rev-macs=(list (unit @ux))  (flop mac-list)
  ?~  rev  ~
  ?~  rev-rngs  ~
  ?~  rev-macs  ~
  ::  final hop layer: next=~, next-cell-id=~, include body-key and rng
  =/  final-layer=header-layer
    [next=~ next-cell-id=~ inner=~ body-key=`body-key rng=`i.rev-rngs delay=delay.i.rev body-mac=i.rev-macs]
  =/  sealed=(unit @ux)
    (seal-to-pub (jam final-layer) pub.i.rev eny)
  ?~  sealed  ~
  =/  acc=header-box  u.sealed
  =/  prev-ship=ship  ship.i.rev
  =/  rest=(list route-hop)  t.rev
  =/  rest-rngs=(list @ux)  t.rev-rngs
  =/  rest-macs=(list (unit @ux))  t.rev-macs
  =/  counter=@ud  1
  |-
  ?~  rest  `[acc rngs]
  ?~  rest-rngs  `[acc rngs]
  ?~  rest-macs  `[acc rngs]
  ::  generate random next-cell-id for forwarding to prev-ship
  =/  cid=@uv  `@uv`(sham [%skein-cid eny counter])
  =/  layer=header-layer
    [`prev-ship `cid `acc ~ `i.rest-rngs delay.i.rest i.rest-macs]
  =/  new-eny=@  (shaz (jam [eny counter]))
  =/  new-sealed=(unit @ux)
    (seal-to-pub (jam layer) pub.i.rest new-eny)
  ?~  new-sealed  ~
  %=  $
    acc  u.new-sealed
    prev-ship  ship.i.rest
    rest  t.rest
    rest-rngs  t.rest-rngs
    rest-macs  t.rest-macs
    counter  +(counter)
  ==
::
++  advance-cell
  |=  [cell=relay-cell layer=header-layer new-body=payload-box]
  ^-  relay-cell
  =/  inner=header-box  ?~(inner.layer 0x0 u.inner.layer)
  =/  cid=@uv  ?~(next-cell-id.layer cell-id.cell u.next-cell-id.layer)
  [cid inner new-body expiry.cell profile.cell]
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
  ::  ws4: pick a profile for cover traffic, weighted toward %small
  =/  roll=@ud  (mod (mug (shaz (jam [eny %cover-profile]))) 10)
  =/  cover-profile=cell-profile
    ?:  (lth roll 6)  %small     ::  60% small
    ?:  (lth roll 9)  %medium    ::  30% medium
    %large                       ::  10% large
  =/  req=send-request  [%cover [%endpoint ship.target %cover] 'cover' [~ ~ ~ `cover-profile]]
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
          relay-metas=(map relay-id relay-meta)
          retries=(list retry-entry)
          minted-contacts=(map @uv @ux)
          profile-counts=[small=@ud medium=@ud large=@ud]
          bundle-progress=(map @ux @ud)
          exhausted-bundles=(set @ux)
          queued-no-route=@ud
          reselected=@ud
          exhausted-reselects=@ud
      ==
  ^-  json
  ::  workstream 1: count relays by status
  =/  status-counts=[prov=@ud usab=@ud trust=@ud]
    %-  ~(rep by relay-metas)
    |=  [[rid=relay-id rm=relay-meta] acc=[prov=@ud usab=@ud trust=@ud]]
    ?-  status.rm
      %provisional  [+(prov.acc) usab.acc trust.acc]
      %usable       [prov.acc +(usab.acc) trust.acc]
      %trusted      [prov.acc usab.acc +(trust.acc)]
    ==
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
      ['provisionalRelays' (numb:enjs:format prov.status-counts)]
      ['usableRelays' (numb:enjs:format usab.status-counts)]
      ['pendingRetries' (numb:enjs:format (lent retries))]
      ['mintedContacts' (numb:enjs:format ~(wyt by minted-contacts))]
      ::  ws4: profile distribution counters
      ['sentSmall' (numb:enjs:format small.profile-counts)]
      ['sentMedium' (numb:enjs:format medium.profile-counts)]
      ['sentLarge' (numb:enjs:format large.profile-counts)]
      ::  ws1/ws2/ws3: bundle lifecycle and no-route counters
      ['bundleProgress' (numb:enjs:format ~(wyt by bundle-progress))]
      ['exhaustedBundles' (numb:enjs:format ~(wyt in exhausted-bundles))]
      ['queuedNoRoute' (numb:enjs:format queued-no-route)]
      ['reselected' (numb:enjs:format reselected)]
      ['exhaustedReselects' (numb:enjs:format exhausted-reselects)]
  ==
::
++  relays-json
  |=  [relays=(map relay-id relay-descriptor) metas=(map relay-id relay-meta)]
  ^-  json
  :-  %a
  %+  turn  ~(tap by relays)
  |=  [rid=relay-id rd=relay-descriptor]
  =/  meta=(unit relay-meta)  (~(get by metas) rid)
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
      ::  workstream 1: provenance metadata
      :-  'status'
      ?~  meta  s+'provisional'
      s+?-(status.u.meta %provisional 'provisional', %usable 'usable', %trusted 'trusted')
      :-  'sources'
      ?~  meta  (numb:enjs:format 0)
      (numb:enjs:format ~(wyt in sources.u.meta))
      ::  ws3: operator family
      :-  'family'
      ?~  meta  ~
      ?~  family.u.meta  ~
      s+u.family.u.meta
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
  |=  [health=(map relay-id [success=@ud failure=@ud last-fail=(unit @da)]) metas=(map relay-id relay-meta)]
  ^-  json
  :-  %a
  %+  turn  ~(tap by health)
  |=  [rid=relay-id h=[success=@ud failure=@ud last-fail=(unit @da)]]
  =/  meta=(unit relay-meta)  (~(get by metas) rid)
  %-  pairs:enjs:format
  :~  ['relay' s+rid]
      ['success' (numb:enjs:format success.h)]
      ['failure' (numb:enjs:format failure.h)]
      :-  'lastFail'
      ?~  last-fail.h  ~
      (numb:enjs:format (div (sub u.last-fail.h ~1970.1.1) ~s1))
      :-  'status'
      ?~  meta  s+'unknown'
      s+?-(status.u.meta %provisional 'provisional', %usable 'usable', %trusted 'trusted')
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
  =.  relay-metas.state  ~
  =.  retries.state  ~
  =.  last-real-send.state  now.bowl
  =.  minted-contacts.state  ~
  =.  consumed-entries.state  ~
  =.  profile-counts.state  [0 0 0]
  =.  bundle-progress.state  ~
  =.  exhausted-bundles.state  ~
  =.  queued-no-route.state  0
  =.  reselected.state  0
  =.  exhausted-reselects.state  0
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
  =.  state  !<(state-0 old)
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
      =/  resolved-rset=(unit route-set)
        ?~  route.opts.req
          ?.  =(ship.ep our.bowl)
            (select-route our.bowl ep relays.state relay-metas.state now.bowl eny.bowl eff-hops health.state recent-routes.state trusted.state)
          ~
        `[(hydrate-route u.route.opts.req relays.state) ~]
      =/  resolved-route=(unit route)
        ?~  resolved-rset  ~
        `primary.u.resolved-rset
      =/  resolved-opts=send-options  [resolved-route reply-blocks.opts.req ttl.opts.req profile.opts.req]
      =/  env=envelope
        [next-id.state (local-endpoint from.req our.bowl) ep now.bowl payload.req resolved-opts]
      =.  next-id.state  +(next-id.state)
      ::  local loopback
      ?:  ?&(=(ship.ep our.bowl) ?=(~ resolved-route))
        ~&  [%skein-send %loopback from.req app.ep]
        =^  cards  queues.state  (deliver-envelope our.bowl env apps.state queues.state)
        [cards this]
      ::  no route — ws2: queue for later reselection instead of dropping
      ?~  resolved-route
        ~&  [%skein-send %no-route-queued from.req (scot %p ship.ep) app.ep]
        =/  prof=cell-profile  (auto-profile (met 3 (jam payload.req)))
        =/  body-key=relay-key  (end [3 32] (shaz (jam [%skein-body eny.bowl id.env])))
        =.  retries.state
          [[env body-key prof ~ 0 (add now.bowl retry-base) default-max-reselects] retries.state]
        =.  queued-no-route.state  +(queued-no-route.state)
        `this
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
      ::  ws4: use caller profile override if provided, else auto-select
      =/  prof=cell-profile
        ?^  profile.opts.req  u.profile.opts.req
        (auto-profile (met 3 body))
      ::  Fix 5: compute body, wrap, MAC, then build header with MACs
      =/  rngs=(list @ux)  (gen-rngs (lent hops.u.resolved-route) eny.bowl)
      =/  wrapped-body=payload-box  (onion-wrap-body body (flop rngs))
      =/  macs=(list (unit @ux))  (compute-body-macs wrapped-body rngs)
      =/  built  (build-header hops.u.resolved-route body-key eny.bowl macs)
      ?~  built
        ~&  [%skein-send %header-build-failed from.req]
        :-  [(relay-card [%dropped cell-id 'header-build-failed'])]~
        this
      ::  workstream 3: pad body and header to profile dimensions
      =/  padded=[body=payload-box header=header-box]
        (pad-to-profile wrapped-body header.u.built prof eny.bowl)
      =/  cell=relay-cell
        [cell-id header.padded body.padded (expiry-for opts.req now.bowl) prof]
      =/  selected=route-log
        [cell-id route-id.u.resolved-route ep (route-ships ep resolved-opts) now.bowl]
      =.  recent-routes.state  (trim-routes [selected recent-routes.state])
      ::  track real sends for adaptive cover traffic
      =?  last-real-send.state  !=(from.req %cover)  now.bowl
      ::  ws4: track profile distribution
      =.  profile-counts.state
        ?-  prof
          %small   profile-counts.state(small +(small.profile-counts.state))
          %medium  profile-counts.state(medium +(medium.profile-counts.state))
          %large   profile-counts.state(large +(large.profile-counts.state))
        ==
      ::  ws2: always store retry entry for non-cover sends with reselection budget
      =/  alts=(list route)
        ?~  resolved-rset  ~
        alternates.u.resolved-rset
      =?  retries.state  !=(from.req %cover)
        [[env body-key prof alts 0 (add now.bowl retry-base) default-max-reselects] retries.state]
      =/  first-hop=(unit route-hop)  (route-head hops.u.resolved-route)
      ::  ws4: use hop delay if specified, otherwise profile-aligned delay
      =/  first-delay=(unit @dr)
        ?~  first-hop  (profile-delay prof)
        ?^  delay.u.first-hop  delay.u.first-hop
        (profile-delay prof)
      =^  cards  mix.state
        (dispatch-cell i.full-route cell first-delay mix.state now.bowl)
      =/  base-cards=(list card)
        :~  (relay-card [%sent cell-id ep])
            (relay-card [%route-selected cell-id u.resolved-route])
        ==
      [(weld base-cards cards) this]
        ::
        ::  %contact: send via contact-bundle (reply-block-routed)
        ::  Fix 1: v2 format — no endpoint in bundle, destination in header only
        ::
        %contact
      =/  cue-result  (mule |.((cue contact-bundle.to.req)))
      ?:  ?=(%| -.cue-result)
        ~&  [%skein-send %contact-cue-failed from.req]
        :-  [(relay-card [%dropped `@uv`0 'contact-cue-failed'])]~
        this
      =/  raw  p.cue-result
      ::  parse intro-v1: [%intro-v1 app bundle-id entries reply-policy]
      ::  or v2: [%contact-v2 app token first-hop header rngs expiry]
      ::  or legacy v1: [%contact-v1 [ship app] [token first-hop header rngs expiry]]
      =/  parse-result
        %-  mule  |.
        ::  ws1: intro-v1 format — pick next unused entry via bundle-progress
        ?:  ?=([%intro-v1 *] raw)
          =/  app=app-id   ;;(@tas +<.raw)
          =/  bid=@ux      ;;(@ux +>-.raw)
          =/  ents=(list *)  ;;((list *) +>+<.raw)
          =/  rpol=(unit ?)  ;;((unit ?) +>+>.raw)
          ?~  ents  !!
          =/  idx=@ud  (~(gut by bundle-progress.state) bid 0)
          =/  n-entries=@ud  (lent ents)
          ?:  (gte idx n-entries)
            ::  bundle exhausted — signal via dummy token 0x0
            =/  ep=endpoint  [*@p app]
            =/  rb=reply-block  [0x0 *@p 0x0 ~ ~]
            [`bid ep rb]
          =/  entry  (snag idx `(list *)`ents)
          =/  token=reply-token  ;;(@ux -.entry)
          =/  fh=ship            ;;(@p +<.entry)
          =/  hdr=header-box     ;;(@ux +>-.entry)
          =/  rngs=(list @ux)    ;;((list @ux) +>+<.entry)
          =/  exp=(unit @da)     ;;((unit @da) +>+>.entry)
          =/  ep=endpoint  [*@p app]
          =/  rb=reply-block  [token fh hdr rngs exp]
          [`bid ep rb]
        ?:  ?=([%contact-v2 *] raw)
          =/  app=app-id   ;;(@tas +<.raw)
          =/  rest  +>.raw
          =/  token=reply-token  ;;(@ux -.rest)
          =/  fh=ship            ;;(@p +<.rest)
          =/  hdr=header-box     ;;(@ux +>-.rest)
          =/  rngs=(list @ux)    ;;((list @ux) +>+<.rest)
          =/  exp=(unit @da)     ;;((unit @da) +>+>.rest)
          ::  dummy endpoint — real destination is in header onion
          =/  ep=endpoint  [*@p app]
          =/  rb=reply-block  [token fh hdr rngs exp]
          [*(unit @ux) ep rb]
        ?>  ?=([%contact-v1 *] raw)
        =/  ep  (endpoint +<.raw)
        =/  rb  (reply-block +>.raw)
        [*(unit @ux) ep rb]
      ?:  ?=(%| -.parse-result)
        ~&  [%skein-send %contact-parse-failed from.req]
        :-  [(relay-card [%dropped `@uv`0 'contact-parse-failed'])]~
        this
      =/  maybe-bid=(unit @ux)  -:p.parse-result
      =/  ep=endpoint  ->-:p.parse-result
      =/  rb=reply-block  ->+:p.parse-result
      ::  ws1: check for bundle exhaustion (signaled by dummy token 0x0)
      ?:  ?&(?=(^ maybe-bid) =(0x0 token.rb))
        ~&  [%skein-send %bundle-exhausted from.req u.maybe-bid]
        =.  exhausted-bundles.state  (~(put in exhausted-bundles.state) u.maybe-bid)
        :-  [(relay-card [%bundle-exhausted u.maybe-bid])]~
        this
      ::  ws1: advance bundle-progress for intro-v1 bundles
      =?  bundle-progress.state  ?=(^ maybe-bid)
        (~(put by bundle-progress.state) u.maybe-bid +((~(gut by bundle-progress.state) u.maybe-bid 0)))
      ::  build envelope — ep may be dummy for v2 bundles
      =/  resolved-opts=send-options  [~ reply-blocks.opts.req ttl.opts.req profile.opts.req]
      =/  env=envelope
        [next-id.state (local-endpoint from.req our.bowl) ep now.bowl payload.req resolved-opts]
      =.  next-id.state  +(next-id.state)
      ::  derive body key from reply-block token
      =/  body-key=relay-key  (end [3 32] (shaz (jam [%reply-body token.rb])))
      =/  body=payload-box  (seal-body body-key env eny.bowl)
      ::  ws4: use caller profile override if provided, else auto-select
      =/  prof=cell-profile
        ?^  profile.opts.req  u.profile.opts.req
        (auto-profile (met 3 body))
      ::  wrap body with reply-block rngs (already in application order)
      =/  wrapped-body=payload-box  (onion-wrap-body body rngs.rb)
      ::  workstream 3: pad body and header to profile dimensions
      =/  padded=[body=payload-box header=header-box]
        (pad-to-profile wrapped-body header.rb prof eny.bowl)
      ::  build cell using the reply-block header
      =/  cell-id=@uv  `@uv`(sham [eny.bowl now.bowl next-id.state])
      =/  cell=relay-cell
        [cell-id header.padded body.padded expiry.rb prof]
      ::  track real sends for adaptive cover traffic
      =?  last-real-send.state  !=(from.req %cover)  now.bowl
      ::  ws4: track profile distribution
      =.  profile-counts.state
        ?-  prof
          %small   profile-counts.state(small +(small.profile-counts.state))
          %medium  profile-counts.state(medium +(medium.profile-counts.state))
          %large   profile-counts.state(large +(large.profile-counts.state))
        ==
      =/  selected=route-log
        [cell-id `@uv`0 ep ~[first-hop.rb] now.bowl]
      =.  recent-routes.state  (trim-routes [selected recent-routes.state])
      =^  cards  mix.state
        (dispatch-cell first-hop.rb cell (profile-delay prof) mix.state now.bowl)
      =/  base-cards=(list card)
        :~  (relay-card [%sent cell-id ep])
        ==
      [(weld base-cards cards) this]
    ==
  ::
      %skein-cell
    ::  crash-safe: any malformed or incompatible cell is dropped, never bail: 3
    =/  cell-result  (mule |.(!<(relay-cell vase)))
    ?:  ?=(%| -.cell-result)
      ~&  [%skein-cell %bad-cell-cast src.bowl]
      `this
    =/  cell=relay-cell  p.cell-result
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
      ~&  [%skein-cell %undecryptable cell-id.cell %from src.bowl]
      :_  this
      [(relay-card [%dropped cell-id.cell 'undecryptable'])]~
    =/  base=(list card)
      [(relay-card [%received cell-id.cell src.bowl])]~
    ::  Fix 5: verify body MAC if present (reply paths omit MAC)
    ?:  ?&  ?=(^ body-mac.u.layer)
            !=(u.body-mac.u.layer (end [3 32] (shaz body.cell)))
        ==
      [(weld base [(relay-card [%dropped cell-id.cell 'body-mac-mismatch'])]~) this]
    ::  peel body onion layer for this hop
    ?~  rng.u.layer
      [(weld base [(relay-card [%dropped cell-id.cell 'no-rng'])]~) this]
    =/  peel-result  (mule |.((onion-peel-body body.cell u.rng.u.layer)))
    ?:  ?=(%| -.peel-result)
      [(weld base [(relay-card [%dropped cell-id.cell 'body-peel-crashed'])]~) this]
    =/  peeled=(unit payload-box)  p.peel-result
    ?~  peeled
      [(weld base [(relay-card [%dropped cell-id.cell 'body-peel-failed'])]~) this]
    ::  check if we are the final destination
    ~&  [%skein-cell %decrypted cell-id.cell %next ?=(^ next.u.layer) %from src.bowl]
    ?~  next.u.layer
      ~&  [%skein-cell %final-destination cell-id.cell]
      ::  final destination — decrypt body
      ?~  body-key.u.layer
        [(weld base [(relay-card [%dropped cell-id.cell 'no-body-key'])]~) this]
      ::  ws1: check consumed ingress — body-key is derived from token
      =/  ingress-key=@ux  u.body-key.u.layer
      ?:  (~(has by consumed-entries.state) ingress-key)
        [(weld base [(relay-card [%dropped cell-id.cell 'consumed-entry'])]~) this]
      ::  ws1: mark entry as consumed
      =.  consumed-entries.state  (~(put by consumed-entries.state) ingress-key now.bowl)
      =/  env=(unit envelope)
        (open-body u.body-key.u.layer u.peeled)
      ?~  env
        [(weld base [(relay-card [%dropped cell-id.cell 'body-unopenable'])]~) this]
      ::  Fix 1: skip ship check for contact-routed v2 (dummy endpoint)
      ::  verify app binding only; *@p target means contact-bundle routed
      ?.  ?|  =(ship.target.u.env our.bowl)
              =(ship.target.u.env *@p)
          ==
        [(weld base [(relay-card [%dropped cell-id.cell 'wrong-target'])]~) this]
      ::  ws1: attach fresh reply material so sender can reach us on new ingress
      =/  eff-hops=@ud
        (effective-min-hops adaptive-hops.state min-hops.state ~(wyt by relays.state))
      =/  fresh-rb
        (build-reply-block our.bowl relays.state relay-metas.state our-seed.state our-pub.state now.bowl eny.bowl eff-hops health.state recent-routes.state trusted.state)
      =/  fresh-blocks=(list reply-block)
        ?~  fresh-rb  ~
        [reply-block.u.fresh-rb]~
      =/  fixed-env=envelope
        u.env(target [our.bowl app.target.u.env])
      ::  append fresh reply blocks to envelope opts
      =/  delivered-env=envelope
        fixed-env(reply-blocks.opts (weld reply-blocks.opts.fixed-env fresh-blocks))
      =^  cards  queues.state
        (deliver-envelope our.bowl delivered-env apps.state queues.state)
      [(weld base cards) this]
    ::  forward to next hop — peel body, reassign cell-id
    ~&  [%skein-cell %forwarding cell-id.cell %to (scot %p u.next.u.layer)]
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
      (give-json-response eyre-id (stats-json our.bowl apps.state relays.state seen.state recent-routes.state mix.state channels.state our-channels.state min-hops.state seeds.state adaptive-hops.state health.state trusted.state relay-metas.state retries.state minted-contacts.state profile-counts.state bundle-progress.state exhausted-bundles.state queued-no-route.state reselected.state exhausted-reselects.state))
    ::
        [%relays ~]
      :_  this
      (give-json-response eyre-id (relays-json relays.state relay-metas.state))
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
      (give-json-response eyre-id (health-json health.state relay-metas.state))
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
      =/  parsed
        %.  jon
        %-  ot:dejs:format
        :~  ['app' so:dejs:format]
            ['label' (se:dejs:format %uv)]
        ==
      `[%mint-contact `@tas`-.parsed `@uv`+.parsed]
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
    ::
        %'set-relay-family'
      =/  parsed
        %.  jon
        %-  ot:dejs:format
        :~  ['relay' so:dejs:format]
            ['family' so:dejs:format]
        ==
      `[%set-relay-family `relay-id`-.parsed `@t`+.parsed]
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
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state our-seed.state)
      :-  :~  (relay-card [%relay-added descriptor.act])
              (pool-fact-card [our-rd (relays-list relays.state)])
          ==
      this
    ::
        %drop-relay
      =.  relays.state  (~(del by relays.state) relay.act)
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state our-seed.state)
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
      =.  retries.state  ~
      ~&  [%skein %cleared-seen-and-retries]
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
        (build-reply-block our.bowl relays.state relay-metas.state our-seed.state our-pub.state now.bowl eny.bowl eff-hops health.state recent-routes.state trusted.state)
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
          app.act  our.bowl  relays.state  relay-metas.state  our-seed.state
          our-pub.state  now.bowl  eny.bowl  eff-hops  health.state
          recent-routes.state  trusted.state
        ==
      ?~  result
        ~&  [%skein %mint-contact-failed app.act %insufficient-relays]
        `this
      ::  ws3: clear exhausted state for old bundle at this label
      =/  old-bundle=(unit @ux)  (~(get by minted-contacts.state) label.act)
      =?  bundle-progress.state  ?=(^ old-bundle)
        =/  old-cue  (mule |.((cue u.old-bundle)))
        ?.  ?=(%& -.old-cue)  bundle-progress.state
        ?.  ?=([%intro-v1 *] p.old-cue)  bundle-progress.state
        =/  old-bid=@ux  ;;(@ux +>-.p.old-cue)
        (~(del by bundle-progress.state) old-bid)
      =?  exhausted-bundles.state  ?=(^ old-bundle)
        =/  old-cue  (mule |.((cue u.old-bundle)))
        ?.  ?=(%& -.old-cue)  exhausted-bundles.state
        ?.  ?=([%intro-v1 *] p.old-cue)  exhausted-bundles.state
        =/  old-bid=@ux  ;;(@ux +>-.p.old-cue)
        (~(del in exhausted-bundles.state) old-bid)
      ::  Fix 2: store per-label (not per-app) so each nym gets unique bundle
      =.  minted-contacts.state  (~(put by minted-contacts.state) label.act u.result)
      ~&  [%skein %contact-minted app.act label.act]
      :-  [(relay-card [%contact-minted app.act label.act])]~
      this
    ::
        %trust-relay
      =.  trusted.state  (~(put in trusted.state) relay.act)
      ::  workstream 1: update relay-meta status to %trusted
      =/  cur-meta=relay-meta  (gut-relay-meta relay.act relay-metas.state now.bowl)
      =.  relay-metas.state
        (~(put by relay-metas.state) relay.act cur-meta(status %trusted))
      ~&  [%skein %relay-trusted relay.act]
      :-  [(relay-card [%relay-trusted relay.act])]~
      this
    ::
        %untrust-relay
      =.  trusted.state  (~(del in trusted.state) relay.act)
      ::  workstream 1: recompute relay-meta status after untrust
      =/  cur-meta=relay-meta  (gut-relay-meta relay.act relay-metas.state now.bowl)
      =/  new-status=relay-status
        ?:  (gte ~(wyt in sources.cur-meta) usable-source-threshold)  %usable
        %provisional
      =.  relay-metas.state
        (~(put by relay-metas.state) relay.act cur-meta(status new-status))
      ~&  [%skein %relay-untrusted relay.act]
      :-  [(relay-card [%relay-untrusted relay.act])]~
      this
    ::
        %set-relay-family
      ::  ws3: assign operator family label to relay
      =/  cur-meta=relay-meta  (gut-relay-meta relay.act relay-metas.state now.bowl)
      =.  relay-metas.state
        (~(put by relay-metas.state) relay.act cur-meta(family `family.act))
      ~&  [%skein %relay-family-set relay.act family.act]
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
  ::
      [%x %reply-block ~]
    ::  build a fresh reply block (informational; use %build-reply-block poke for tracked blocks)
    =/  eff-hops=@ud
      (effective-min-hops adaptive-hops.state min-hops.state ~(wyt by relays.state))
    =/  result
      (build-reply-block our.bowl relays.state relay-metas.state our-seed.state our-pub.state now.bowl eny.bowl eff-hops health.state recent-routes.state trusted.state)
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
    ::  Fix 2: scry by label (@uv) instead of app-id
    =/  label=@uv  (slav %uv i.t.t.path)
    =/  bundle  (~(get by minted-contacts.state) label)
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
    =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state our-seed.state)
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
      ::  crash-safe: reject incompatible descriptor formats (e.g. pre-sig)
      =/  pool-cast  (mule |.(!<((list relay-descriptor) q.cage.sign)))
      ?:  ?=(%| -.pool-cast)
        ~&  [%skein %relay-pool %type-mismatch source=(slav %p i.t.t.wire)]
        `this
      =/  pool=(list relay-descriptor)  p.pool-cast
      =/  source=ship  (slav %p i.t.t.wire)
      =/  [new-rds=(list relay-descriptor) new-relays=(map relay-id relay-descriptor) new-metas=(map relay-id relay-meta)]
        (merge-relays our.bowl pool relays.state relay-metas.state trusted.state source now.bowl)
      ::  workstream 1: always update metas (source tracking for existing relays)
      =.  relay-metas.state  new-metas
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
      =/  our-rd=relay-descriptor  (self-descriptor our.bowl our-pub.state our-seed.state)
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
      =/  upd-cast  (mule |.(!<(channel-update q.cage.sign)))
      ?:  ?=(%| -.upd-cast)
        ~&  [%skein %channel-fact %type-mismatch relay-ship cid]
        `this
      =/  upd=channel-update  p.upd-cast
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
    =.  relay-metas.state
      =/  ss  relay-metas.state
      =/  rids  expired-rids
      |-
      ?~  rids  ss
      $(rids t.rids, ss (~(del by ss) i.rids))
    ::  process retry queue — rebuild cells for alternate routes on retry
    ::  ws2: reselect fresh routes when alternates are exhausted
    =/  due=(list retry-entry)
      (skim retries.state |=(re=retry-entry (lte next-try.re now.bowl)))
    =/  not-due=(list retry-entry)
      (skip retries.state |=(re=retry-entry (lte next-try.re now.bowl)))
    ::  ws2: for entries with exhausted routes and remaining reselect budget,
    ::  call select-route fresh against current relay pool
    =/  due=(list retry-entry)
      %+  turn  due
      |=  re=retry-entry
      ?.  ?&(=(~ routes.re) (gth max-reselects.re 0))
        re
      =/  eff-hops=@ud
        (effective-min-hops adaptive-hops.state min-hops.state ~(wyt by relays.state))
      =/  retry-eny=@  (shaz (jam [eny.bowl %reselect attempts.re id.env.re]))
      =/  fresh-rset=(unit route-set)
        (select-route our.bowl target.env.re relays.state relay-metas.state now.bowl retry-eny eff-hops health.state recent-routes.state trusted.state)
      ?~  fresh-rset  re
      =/  new-routes=(list route)
        [primary.u.fresh-rset alternates.u.fresh-rset]
      ~&  [%skein-retry %reselected id.env.re %budget (dec max-reselects.re) %routes (lent new-routes)]
      re(routes new-routes, max-reselects (dec max-reselects.re))
    ::  ws2: count successful reselections and exhaustions
    =.  reselected.state
      %+  add  reselected.state
      %-  lent
      %+  skim  due
      |=  re=retry-entry
      ?=(^ routes.re)
    =.  exhausted-reselects.state
      %+  add  exhausted-reselects.state
      %-  lent
      %+  skim  due
      |=  re=retry-entry
      ?&(=(~ routes.re) =(0 max-reselects.re))
    ::  rebuild and send cells for each due retry's next route
    =/  retry-cards=(list card)
      %+  murn  due
      |=  re=retry-entry
      ?~  routes.re  ~
      =/  rte=route  i.routes.re
      ::  derive fresh entropy per retry to avoid cell-id collisions
      =/  retry-eny=@  (shaz (jam [eny.bowl attempts.re id.env.re]))
      =/  built  (build-cell-for-route env.re body-key.re rte prof.re retry-eny now.bowl)
      ?~  built
        ~&  [%skein-retry %rebuild-failed id.env.re]
        ~
      ~&  [%skein-retry %sending id.env.re %attempt +(attempts.re) %via (lent hops.rte) %hops]
      `(send-cell-card first-hop.u.built cell.u.built)
    ::  re-queue with incremented attempts, drop maxed-out and fully exhausted entries
    =/  requeued=(list retry-entry)
      %+  murn  due
      |=  re=retry-entry
      ?:  (gte +(attempts.re) max-retries)  ~
      ::  ws2: keep entry if routes remain OR reselect budget remains
      ?:  ?&(=(~ routes.re) =(0 max-reselects.re))  ~
      =/  backoff=@dr  (mul retry-base (bex attempts.re))
      ::  rotate routes: consume head if present, keep rest
      =/  remaining-routes=(list route)
        ?~  routes.re  ~
        t.routes.re
      `[env.re body-key.re prof.re remaining-routes +(attempts.re) (add now.bowl backoff) max-reselects.re]
    =.  retries.state  (weld requeued not-due)
    ::  ws1: prune consumed entries older than 1 day
    =.  consumed-entries.state
      =/  cutoff=@da  (sub now.bowl ~d1)
      %-  ~(rep by consumed-entries.state)
      |=  [[key=@ux at=@da] out=(map @ux @da)]
      ?:  (lth at cutoff)  out
      (~(put by out) key at)
    ::  ws3: prune bundle-progress for exhausted bundles (keep active ones)
    ::  and clear exhausted-bundles in sync
    =.  bundle-progress.state
      %-  ~(rep by bundle-progress.state)
      |=  [[bid=@ux idx=@ud] out=(map @ux @ud)]
      ?:  (~(has in exhausted-bundles.state) bid)  out
      (~(put by out) bid idx)
    =.  exhausted-bundles.state  ~
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
