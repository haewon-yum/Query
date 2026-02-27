

  DECLARE start_date DATE DEFAULT '2024-08-01';
  DECLARE end_date DATE DEFAULT '2025-07-31';

  
  
  SELECT
    fact_app.app_market_bundle,
    fact_app.unified_app_id,
    fact_app.dim1_app.unified_app_name,
    fact_app.dim1_app.app_release_date_utc,
    DATE(fact_app.date_utc) AS date,
    SUM(fact_app.monthly.downloads) AS monthly_downloads,
    SUM(fact_app.monthly.active_users) AS mau,
    SUM(fact_app.monthly.revenue) AS monthly_revenue, 
    SUM(fact_app.monthly.installed_users) AS monthly_installed_users
  FROM `moloco-ae-view.athena.fact_app` fact_app
  WHERE 1=1
    AND fact_app.app_market_bundle IN ('6740026253','1557392270','1538912205','in.ludo.supremegold','com.greenmushroom.boomblitz.gp','com.igg.android.vikingriseglobal','6738469826','6444487398','6443581187','com.realmsofpixel.ng','1580298959','1453651052','com.bingo.legends.game','1420058690','6478478655','1552206075','6667111749','com.a3.topgirl.gplay.kr','com.readygo.dark.gp','6448786147','6448696907','com.quiz.talent.machine','6451399876','6446308106','6499293031','com.duige.hzw.multilingual','com.bingo.tricks.circus','6738897614','6566176181','com.rummytime.googleplay','1589643727','6503700976','6471045672','paint.by.number.pixel.art.coloring.drawing.puzzle','com.bitmango.go.bubblepop','6446284100','com.tap4fun.odin.kingdomguard','6737597430','6743824718','com.solvabet.zeus','com.star.union.planetant','6738942733','6711332789','6474962684','6443823893','com.ludosupreme.zupee','6737500275','com.kr.firegp','1662742277','6737767831','com.fatmerge.global','6723868320','1463509237','6745258320','com.slots.free.vegas.casino.jackpotland','com.sdhauhi.fahfha','6733228623','6737655128','com.zzqifufysrh.mdiwuniuqwpiclus','com.rummy.prime.card.games','6446389130','com.joycastle.mergematch','com.serendipitous.scratchers.lottery','6740840220','in.playsimple.tripcross','6443755785','com.funplus.mc','1668656321','sphacelus.nucleoplasm.dcs.odin.bea','1479198816','com.cookapps.catshinobi','com.seaofconquest.global','6479229586','com.krafton.dndm','com.games24x7.rummycircle.rummy','6505095234','com.topultragame.slotlasvega','happy.paint.coloring.color.number','1462877149','com.TGames.SkyJump','6478530492','screw.sort.match.jam.puzzle','1637363937','com.camelgames.superking','6738346197','com.nexon.mod','com.zzsjkr.google','com.mystery.treasurespins','com.global.mus','com.spcomes.hellotown','1020109860','com.agame.hmt.kr.gp','com.spin.fish.game','6738599764','1576310504','com.allstarunion.beastlord','6723883406','6453111576','6443577184','6479020757','com.jackpotfriends.slots','com.pubg.imobile','6443467666','6740016798','6482099823','1312031248','in.glg.tajrummy','com.mqifuyswsf.cpqoiauooqwis','com.jmsgame.jackpotmastercasino','6471572249','com.mysticspin.slots','1098157959','6475033368','6449289088','com.gamedots.seasideescape','6449822109','6474961936','1304885184','1623318294','1585915174','com.solitaire.cards.deluxe','1071744151','com.bnoquyhw.yuiqhgbsq','6738905436','6737509404','com.zupee.free','6670604287','com.fun.lastwar.gp','com.igg.android.doomsdaylastsurvivors','1277029359','1441742921','com.seaofconquest.gpru','com.gof.global','1598843828','com.wemadeconnect.aos.lostdgl','6478063606','1660171117','com.global.musru','6443467980','6547835725','1530025009','1558803930','1523820531','6737788333','6502750094','6479595079','slots.pcg.casino.games.free.android','852912420','6482849843','com.qjzj4399kr.google','com.kurogame.wutheringwaves.global','com.kingsgroup.dcdly','1476370680','com.netmarble.rfnext','6737323016','6739554056','com.mars.avgchapters','com.slotempire.jackpot.bonanza.vegas.casino','com.vitastudio.mahjong','1611490041','com.playfungame.dream','6738273798','6736896540','6738647276','6593673337','1608880742','com.pusoydosgo.play','com.nnsiwuqwiist.gjjwkwiisuwyq','6526483945','6740383289','com.elemania.slots.word.android','com.bubble.world.game.splash','887947640','com.mechanist.vampire.aos','1356980152','6738732331','com.playfungame.dream','com.gogoldminds.word','6739792763','6738691208','6468921495','1347780764','com.global.pnckru','com.boom.rummyverseplaystore','6744522497','6471960010','1581431235','6449583996','com.topwar.gp','6740621218','com.gameskraft.rummycultureplay','6742445632','1529572983','puzzle.blockpuzzle.cube.relax','1553717881','com.zhushendl.tgp','1508251903','6511224754','6529538542','com.wwv.global','6451460845','1579464667','com.proxima.dfm','wood.block.crush.adventure.puzzle.games','screw.puzzle.match3.brain.puzz','com.allstarunion.beastlord.kr','com.luckygold.rush','in.playsimple.wordsearch','easy.sudoku.puzzle.solver.free','6737978384','com.estar.isekai.kr','6456324252','1589762792','6670441558','6443575749','com.onemt.and.kc','closet.match.pair.matching.games','com.diamondlife.slots.vegas.free','com.casino.keepbet.android','6446005634','6482291732','com.funtriolimited.slots.casino.free','com.entropy.global','6478530320','com.dominovamos.play','1376515087','com.camelgames.aoz','6739694698','6633425539','1265838130','1617391485','com.topgamesinc.evony','com.vm3.global','com.run.tower.defense','com.grandegames.slots.dafu.casino','6717586224','6743262846','1441199787','6743212760','com.upswing.slots','1556357398','slots.dcg.casino.games.free.android','com.koykogames.Euphoria21Adventure','com.a3.topgirl.gplay','6738633706')
    AND DATE(fact_app.date_utc) BETWEEN start_date AND end_date
    AND fact_app.monthly.active_users > 0
  GROUP BY 1,2,3,4,5
  ORDER BY 1,2,3,5




