/+  *test
|%
++  test-sanity  (expect-eq !>(2) !>((add 1 1)))
++  test-crub
  =/  key=@ux  (shaz 'key')
  =/  data=@  (jam 'data')
  (expect-eq !>(`data) !>((de:crub:crypto key (en:crub:crypto key data))))
++  test-ed25519
  =/  s=@ux  (end [3 32] (shaz 'ed'))
  =/  p=@ux  `@ux`(puck:ed:crypto s)
  =/  m=@  (jam 'hello')
  (expect-eq !>(%.y) !>((veri:ed:crypto (sign:ed:crypto m s) m p)))
++  test-dh
  =/  sa=@ux  (end [3 32] (shaz 'a'))
  =/  sb=@ux  (end [3 32] (shaz 'b'))
  (expect-eq !>((shar:ed:crypto `@ux`(puck:ed:crypto sb) sa)) !>((shar:ed:crypto `@ux`(puck:ed:crypto sa) sb)))
++  test-body-mac
  =/  b=@ux  `@ux`(jam 'test')
  (expect-eq !>(%.n) !>(=((end [3 32] (shaz b)) (end [3 32] (shaz (mix b 0x1))))))
++  test-onion-3-layers
  =/  body=@ux  `@ux`(jam 'payload')
  =/  r1=@ux  (shaz 'r1')
  =/  r2=@ux  (shaz 'r2')
  =/  r3=@ux  (shaz 'r3')
  =/  wrapped=@ux  (en:crub:crypto r1 (en:crub:crypto r2 (en:crub:crypto r3 body)))
  =/  p1  (de:crub:crypto r1 wrapped)
  ?~  p1  (expect-eq !>('fail') !>('p1'))
  =/  p2  (de:crub:crypto r2 u.p1)
  ?~  p2  (expect-eq !>('fail') !>('p2'))
  =/  p3  (de:crub:crypto r3 u.p2)
  ?~  p3  (expect-eq !>('fail') !>('p3'))
  (expect-eq !>(body) !>(u.p3))
++  test-contact-v2-format
  =/  b=@ux  `@ux`(jam [%contact-v2 %test (shaz 'tok') ~zod (shaz 'hdr') ~[(shaz 'rng')] `~2025.12.31])
  =/  raw  (cue b)
  ?>  ?=([%contact-v2 *] raw)
  (expect-eq !>(%test) !>(;;(@tas +<.raw)))
++  test-intro-v1-format
  =/  tok1=@ux  (shaz 't1')
  =/  tok2=@ux  (shaz 't2')
  =/  b=@ux  `@ux`(jam [%intro-v1 %test (shaz 'bid') [[tok1 ~zod (shaz 'h') ~[(shaz 'r')] ~] [tok2 ~zod (shaz 'h') ~[(shaz 'r')] ~] ~] ~])
  =/  raw  (cue b)
  ?>  ?=([%intro-v1 *] raw)
  (expect-eq !>(%test) !>(;;(@tas +<.raw)))
++  test-descriptor-sig
  =/  seed=@ux  (end [3 32] (shaz 'relay'))
  =/  pub=@ux   `@ux`(puck:ed:crypto seed)
  =/  msg=@  (jam ['~r' ~sampel-palnet pub 1])
  (expect-eq !>(%.y) !>((veri:ed:crypto (sign:ed:crypto msg seed) msg pub)))
++  test-descriptor-sig-bad
  =/  seed=@ux  (end [3 32] (shaz 'relay'))
  =/  pub=@ux   `@ux`(puck:ed:crypto seed)
  =/  bad=@ux  (sign:ed:crypto (jam 'wrong') seed)
  (expect-eq !>(%.n) !>((veri:ed:crypto bad (jam ['~r' ~sampel-palnet pub 1]) pub)))
++  test-bundle-progress
  =/  bp=(map @ux @ud)  ~
  =/  bid=@ux  (shaz 'bid')
  =/  i0=@ud  (~(gut by bp) bid 0)
  =.  bp  (~(put by bp) bid +(i0))
  =/  i1=@ud  (~(gut by bp) bid 0)
  =.  bp  (~(put by bp) bid +(i1))
  ;:  weld
    (expect-eq !>(0) !>(i0))
    (expect-eq !>(1) !>(i1))
    (expect-eq !>(2) !>((~(gut by bp) bid 0)))
  ==
++  test-consumed-entry
  =/  c=(map @ux @da)  ~
  =/  k=@ux  (shaz 'ingress')
  =/  a=?  (~(has by c) k)
  =.  c  (~(put by c) k ~2025.1.1)
  ;:  weld
    (expect-eq !>(%.n) !>(a))
    (expect-eq !>(%.y) !>((~(has by c) k)))
  ==
++  test-seen-prune
  =/  now=@da  ~2025.1.1
  =/  seen=(map @uv @da)
    (~(put by (~(put by *(map @uv @da)) 0v1 (sub now ~h2))) 0v2 (sub now ~m30))
  =/  cutoff=@da  (sub now ~h1)
  =/  pruned=(map @uv @da)
    %-  ~(rep by seen)
    |=  [[cid=@uv at=@da] out=(map @uv @da)]
    ?:((lth at cutoff) out (~(put by out) cid at))
  ;:  weld
    (expect-eq !>(%.n) !>((~(has by pruned) 0v1)))
    (expect-eq !>(%.y) !>((~(has by pruned) 0v2)))
  ==
++  test-auto-profile
  =/  auto
    |=  s=@ud
    ^-  ?(%small %medium %large)
    ?:((lte s 8.192) %small ?:((lte s 32.768) %medium %large))
  ;:  weld
    (expect-eq !>(%small) !>((auto 100)))
    (expect-eq !>(%small) !>((auto 8.192)))
    (expect-eq !>(%medium) !>((auto 8.193)))
    (expect-eq !>(%large) !>((auto 32.769)))
  ==
--
