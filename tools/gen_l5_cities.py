# Injects the HSK-5 (Level 5) unit-city Landmark data into cities.dart (24 new
# cities, 96 landmarks). Icon art comes from tools/fetch_all_icons.py
# (globally-unique icons8 set). After: extend fetch_all_icons.py, regenerate packs.
import os, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

C = {
 'sanming': [
  ('danxia', 'Taining Danxia', 'Taining Danxia', "Kızıl kayalıkları ve kanyonlarıyla UNESCO jeoparkı, gökten inmiş bir taş labirentidir.", "With red cliffs and gorges, the UNESCO geopark is a maze of stone fallen from the sky."),
  ('shaxian', 'Sha İlçesi Atıştırmalıkları', 'Sha County Snacks', "Ucuz wonton ve karışık eriştesiyle Sha İlçesi mutfağı tüm Çin'e yayıldı.", "With cheap wontons and mixed noodles, Sha County snacks have spread across all China."),
  ('forest', 'Yeşil Başkent', 'Green Capital', "Çin'in en ormanlık şehri Sanming, temiz havası ve yeşil dağlarıyla nefes aldırır.", "China's most forested city, Sanming breathes with clean air and green mountains."),
  ('goldenlake', 'Altın Göl', 'Golden Lake', "Danxia kayalıkları arasında uzanan göl, tekne turlarıyla keşfedilir.", "Stretching among the Danxia cliffs, the lake is explored by boat.")],
 'ningde': [
  ('mudflat', 'Xiapu Gelgit Düzlükleri', 'Xiapu Mudflats', "Gelgitle değişen ışıltılı çamur düzlükleri, dünyanın en çok fotoğraflanan kıyılarındandır.", "Shimmering tidal flats shifting with the sea are among the world's most photographed shores."),
  ('whitetea', 'Fuding Beyaz Çayı', 'Fuding White Tea', "Tüylü tomurcuklarıyla kurutulan beyaz çay, yıllandıkça değer kazanır.", "Dried with downy buds, the white tea grows more prized as it ages."),
  ('taimu', 'Taimu Dağı', 'Mount Taimu', "Denize bakan granit kuleleri ve mağaralarıyla dağ, 'denizin yanındaki peri diyarı'dır.", "With granite spires and caves above the sea, the mountain is a 'fairyland by the sea'."),
  ('croaker', 'Sarı Kroker Balığı', 'Yellow Croaker', "Sakin koylarda yetiştirilen büyük sarı kroker balığı, şehrin deniz hazinesidir.", "Large yellow croaker farmed in sheltered bays is the city's marine treasure.")],
 'shaoguan': [
  ('redcliff', 'Danxia Dağı', 'Mount Danxia', "'Danxia' yer şeklinin adını aldığı kızıl kayalık dağ, eşsiz oyma kuleleriyle ünlüdür.", "The red rock mountain that named the 'Danxia' landform is famed for its carved pillars."),
  ('chantemple', 'Nanhua Tapınağı', 'Nanhua Temple', "Zen Budizminin Altıncı Patriği Huineng'in tapınağı, mezhebin kutsal merkezidir.", "Temple of Huineng, Sixth Patriarch of Chan Buddhism, it is the sect's sacred centre."),
  ('ancestor', 'Zhuji Sokağı', 'Zhuji Lane', "Milyonlarca güneyli Çinlinin atalarının göç ettiği sokak, bir kök-bulma yeridir.", "The lane from which millions of southern Chinese trace their migrating ancestors is a place of roots."),
  ('yaodance', 'Yao Halkı', 'Yao People', "Dağ köylerinde yaşayan Yao halkı, rengârenk kostümleri ve davullu danslarıyla bilinir.", "Living in mountain villages, the Yao people are known for colourful costumes and drum dances.")],
 'zhanjiang': [
  ('oyster', 'Zhanjiang İstiridyesi', 'Zhanjiang Oyster', "Sıcak güney sularında yetişen iri istiridyeler, kömürde ızgara edilip sofraları süsler.", "Plump oysters grown in warm southern waters are grilled over coals to grace the table."),
  ('navy', 'Donanma Limanı', 'Naval Port', "Güney Deniz Filosu'na ev sahipliği yapan derin liman, ülkenin güney deniz kapısıdır.", "Home to the South Sea Fleet, the deep port is the nation's southern sea gate."),
  ('mangrove', 'Mangrov Ormanı', 'Mangrove Forest', "Çin'in en büyük mangrov ormanı, gelgit sularında balıkçıllara ve yengeçlere yuva olur.", "China's largest mangrove forest shelters egrets and crabs in its tidal waters."),
  ('donghai', 'Donghai Adası', 'Donghai Island', "Uzun kumsalı ve rüzgârıyla ada, güneşlenme ve sörfün gözde durağıdır.", "With a long beach and steady wind, the island is a favourite for sunbathing and surfing.")],
 'maoming': [
  ('lychee', 'Liçi Başkenti', 'Lychee Capital', "Çin'in en büyük liçi üreticisi Maoming, imparatorlara liçi yollayan topraklardır.", "China's largest lychee producer, Maoming is the land that once sent lychees to emperors."),
  ('refinery', 'Petrokimya Üssü', 'Petrochemical Base', "Güney Çin'in en büyük rafinerilerinden biri, şehrin sanayi gücünü besler.", "One of southern China's largest refineries powers the city's industrial might."),
  ('ladyxian', 'Lady Xian', 'Lady Xian', "Güneyi birleştiren kadın kahraman Lady Xian, halkın bin yıldır andığı bir efsanedir.", "Lady Xian, the heroine who unified the south, has been honoured by the people for a thousand years."),
  ('seaside', 'Sahil', 'Seaside', "'Çin'in Bir Numaralı Plajı' sayılan uzun sahil, ailelere altın kumlar sunar.", "Hailed as 'China's No.1 Beach', the long shore offers families golden sands.")],
 'zhaoqing': [
  ('sevenstar', 'Yedi Yıldız Kayalıkları', 'Seven Star Crags', "Göl üstünde yükselen yedi kireçtaşı tepe, 'Guangdong'un Guilin'i' diye anılır.", "Seven limestone crags rising from a lake are called the 'Guilin of Guangdong'."),
  ('inkstone', 'Duan Mürekkep Taşı', 'Duan Inkstone', "Kaligrafinin dört hazinesinden Duan mürekkep taşı, bin yıldır burada yontulur.", "The Duan inkstone, one of calligraphy's four treasures, has been carved here for a thousand years."),
  ('dinghu', 'Dinghu Dağı', 'Mount Dinghu', "Çin'in ilk doğa koruma alanı, gür yağmur ormanı ve şelaleleriyle 'canlı oksijen barı'dır.", "China's first nature reserve, with lush rainforest and falls, is a living 'oxygen bar'."),
  ('songwall', 'Song Şehir Suru', 'Song City Wall', "Tam korunmuş Song dönemi suru, antik Zhaoqing'i bir tarih halkasıyla sarar.", "The fully preserved Song-era wall rings old Zhaoqing with a circle of history.")],
 'huizhou': [
  ('westlake', 'Huizhou Batı Gölü', 'Huizhou West Lake', "Şair Su Shi'nin sürgünde sevdiği göl, söğütleri ve setleriyle bir şiirdir.", "Loved by the exiled poet Su Shi, the lake is a poem of willows and causeways."),
  ('luofu', 'Luofu Dağı', 'Mount Luofu', "Taocu münzevilerin ve şifalı bitkilerin dağı, 'güneyin ilk kutsal dorukları'ndandır.", "Mountain of Taoist hermits and healing herbs, it is among 'the south's first sacred peaks'."),
  ('alchemy', 'Ge Hong Simyası', 'Ge Hong Alchemy', "Simyacı-hekim Ge Hong, geleneksel tıbbın temellerini bu dağda yazdı.", "The alchemist-physician Ge Hong wrote the foundations of traditional medicine on this mountain."),
  ('xunliao', 'Xunliao Körfezi', 'Xunliao Bay', "Berrak suları ve yumuşak kumuyla körfez, güney sahilinin sakin tatil noktasıdır.", "With clear water and soft sand, the bay is the south coast's tranquil resort.")],
 'meizhou': [
  ('weilongwu', 'Hakka Başkenti', 'Hakka Capital', "'Dünya Hakka başkenti' Meizhou, at nalı biçimli geleneksel weilongwu evleriyle bilinir.", "The 'world Hakka capital', Meizhou is known for its horseshoe-shaped weilongwu homes."),
  ('saltchicken', 'Tuzda Tavuk', 'Salt-Baked Chicken', "Sıcak tuza gömülerek pişirilen Hakka tavuğu, narin etiyle imza lezzettir.", "Hakka chicken baked buried in hot salt is a signature dish of tender meat."),
  ('football', 'Futbolun Memleketi', 'Home of Football', "Çin futbolunun beşiği sayılan şehir, ülkeye nesiller boyu yıldız oyuncu yetiştirdi.", "Regarded as a cradle of Chinese football, the city has raised star players for generations."),
  ('plum', 'Erik Çiçeği', 'Plum Blossom', "Adı 'erik' anlamına gelen şehir, kışın açan erik çiçekleriyle bezenir.", "The city whose name means 'plum' is adorned with plum blossoms in winter.")],
 'jiangmen': [
  ('diaolou', 'Kaiping Kuleleri', 'Kaiping Diaolou', "Yurtdışından dönen göçmenlerin yaptığı çok katlı kale-kuleler UNESCO mirasıdır.", "The multi-storey fortress-towers built by returning emigrants are UNESCO-listed."),
  ('qiaoxiang', 'Gurbetçi Diyarı', 'Overseas Chinese Home', "Dünyaya yayılmış milyonlarca gurbetçinin memleketi, Doğu-Batı kültürünü harmanlar.", "Hometown of millions of overseas Chinese, it blends East and West."),
  ('chenpi', 'Xinhui Mandalina Kabuğu', 'Dried Tangerine Peel', "Yıllandırılan Xinhui mandalina kabuğu, hem baharat hem değerli bir ilaçtır.", "Aged Xinhui tangerine peel is both a spice and a prized medicine."),
  ('birds', 'Kuşlar Cenneti', 'Birds Paradise', "Tek bir dev banyan ağacının oluşturduğu koru, on binlerce balıkçıla yuva olur.", "A grove formed from a single giant banyan tree is home to tens of thousands of egrets.")],
 'yangjiang': [
  ('knife', 'Bıçak Başkenti', 'Knife Capital', "Çin'in mutfak bıçaklarının büyük kısmı, asırlık demircilik geleneğiyle burada dövülür.", "A huge share of China's kitchen knives are forged here by a centuries-old smithing tradition."),
  ('shipwreck', 'Nanhai 1 Batığı', 'Nanhai No.1 Wreck', "Deniz İpek Yolu'ndan kalan Song gemisi, hazinesiyle bir su altı müzesinde sergilenir.", "A Song-era ship from the Maritime Silk Road is displayed with its treasure in an underwater museum."),
  ('hailing', 'Hailing Adası', 'Hailing Island', "Güneşli plajları ve dalgalarıyla ada, Guangdong'un gözde deniz tatil yeridir.", "With sunny beaches and waves, the island is Guangdong's favourite seaside resort."),
  ('kite', 'Uçurtma Şehri', 'Kite City', "Weifang'la birlikte Çin'in iki uçurtma başkentinden biri, gökyüzünü her sonbahar süsler.", "One of China's two kite capitals alongside Weifang, it fills the autumn sky.")],
 'qingyuan': [
  ('rafting', 'Rafting Diyarı', 'Rafting Capital', "Coşkun dağ dereleriyle Qingyuan, Çin'in 'rafting memleketi' diye anılır.", "With rushing mountain streams, Qingyuan is called China's 'home of rafting'."),
  ('chicken', 'Qingyuan Tavuğu', 'Qingyuan Chicken', "İnce kemikli, lezzetli yerel tavuk ırkı, Kanton sofrasının en aranan kümes hayvanıdır.", "The fine-boned, flavourful local chicken breed is the most sought-after fowl on the Cantonese table."),
  ('hotspring', 'Kaplıcalar', 'Hot Springs', "Dağ vadilerinden çıkan sıcak mineralli sular, hafta sonu kaçamaklarının merkezidir.", "Hot mineral waters from the mountain valleys are the centre of weekend escapes."),
  ('yaoterrace', 'Yao Pirinç Terasları', 'Yao Rice Terraces', "Liannan Yao halkının dağ yamaçlarına oyduğu teraslar, asırlık emeğin merdivenidir.", "Terraces carved into the slopes by the Liannan Yao are a staircase of centuries of toil.")],
 'chaozhou': [
  ('guangjibridge', 'Guangji Köprüsü', 'Guangji Bridge', "Ortasındaki sandallarla açılıp kapanan antik köprü, Çin'in dört ünlü köprüsünden biridir.", "The ancient bridge that opens and closes with boats at its centre is one of China's four famous bridges."),
  ('woodcarving', 'Yaldızlı Ahşap Oyma', 'Gilded Woodcarving', "Altın varakla kaplı çok katmanlı ahşap oymalar, tapınakları ışıltıyla doldurur.", "Gold-leafed, multi-layered woodcarvings fill the temples with shimmer."),
  ('chaoxiu', 'Chaozhou İşlemesi', 'Chaozhou Embroidery', "Kabartmalı altın iplik nakışıyla Chaozhou işlemesi, güney Çin'in en gösterişlisidir.", "With raised gold-thread stitching, Chaozhou embroidery is the most opulent in southern China."),
  ('kaiyuan', 'Kaiyuan Tapınağı', 'Kaiyuan Temple', "1.200 yıllık tapınak, Tang döneminden kalma sakin avlularıyla şehrin kalbidir.", "The 1,200-year-old temple, with calm Tang-era courtyards, is the heart of the city.")],
 'jieyang': [
  ('citygate', 'Jinxian Kapısı', 'Jinxian Gate', "Nehre bakan zarif ahşap kule kapısı, antik Jieyang'ın ayakta kalan simgesidir.", "The graceful timber tower gate over the river is the surviving emblem of old Jieyang."),
  ('jade', 'Yeşim Başkenti', 'Jade Capital', "Yangmei kasabası, Çin'in en büyük yeşim oyma ve ticaret merkezlerindendir.", "The town of Yangmei is one of China's largest jade carving and trading hubs."),
  ('jieyanglou', 'Jieyang Kulesi', 'Jieyang Tower', "Geleneksel saçaklı dev kule, Chaoshan kültürünün modern bir anıtıdır.", "The giant tower with traditional eaves is a modern monument to Chaoshan culture."),
  ('beefbroth', 'Chaoshan Dana Çorbası', 'Chaoshan Beef Broth', "Taze dananın berrak suda anında haşlandığı çorba, bölgenin gurur lezzetidir.", "Fresh beef blanched in a clear broth is the region's prized dish.")],
 'yunfu': [
  ('marble', 'Taş Krallığı', 'Stone Kingdom', "Mermer ve taş işlemenin başkenti Yunfu, dünyaya cilalı taş ihraç eder.", "Capital of marble and stone working, Yunfu exports polished stone to the world."),
  ('patriarch', 'Altıncı Patrik', 'Sixth Patriarch', "Zen ustası Huineng'in doğduğu topraklar, Guoen Tapınağı ile kutsanır.", "Birthplace of the Chan master Huineng, the land is hallowed by the Guoen Temple."),
  ('tianlu', 'Tianlu Dağı', 'Mount Tianlu', "Bulutlara değen zirveleri ve çay bahçeleriyle dağ, şehrin yeşil tacıdır.", "With cloud-touched peaks and tea gardens, the mountain is the city's green crown."),
  ('xijiang', 'Batı Nehri', 'West River', "Güneyin büyük su yolu olan İnci Nehri'nin ana kolu, şehrin önünden akar.", "The main branch of the Pearl River, the south's great waterway, flows past the city.")],
 'liuzhou': [
  ('luosifen', 'Salyangoz Eriştesi', 'Snail Rice Noodles', "Keskin kokulu ekşi-acı salyangoz eriştesi 'luosifen', tüm Çin'i saran bir lezzettir.", "Pungent, sour-spicy snail rice noodles, 'luosifen', are a flavour craze sweeping all China."),
  ('autocity', 'Otomobil Şehri', 'Auto City', "Halkın aldığı küçük şehir araçlarıyla Liuzhou, Çin'in en büyük otomobil üslerindendir.", "With the small city cars its people love, Liuzhou is one of China's biggest auto bases."),
  ('karst', 'Liu Nehri Karstı', 'Liu River Karst', "Şehri saran kireçtaşı tepeler ve nehir kıvrımı, sanayi kentine doğa güzelliği katar.", "Limestone hills and a river bend wrapping the city lend natural beauty to the industrial town."),
  ('liuhou', 'Şair Liu Zongyuan', 'Poet Liu Zongyuan', "Tang şairi ve valisi Liu Zongyuan'ın anısı, şehir parkında bir tapınakla yaşar.", "The memory of Tang poet and governor Liu Zongyuan lives in a shrine in the city park.")],
 'wuzhou': [
  ('gemstone', 'Yapay Mücevher Başkenti', 'Gemstone Capital', "Dünya yapay değerli taşlarının büyük kısmı, bu nehir kentinin atölyelerinde kesilir.", "A huge share of the world's man-made gemstones is cut in this river city's workshops."),
  ('liubaotea', 'Liubao Çayı', 'Liubao Dark Tea', "Yıllandırılan koyu Liubao çayı, nemli güneyin sindirim dostu klasik içeceğidir.", "Aged dark Liubao tea is the humid south's digestive classic."),
  ('turtlejelly', 'Kaplumbağa Jölesi', 'Turtle Jelly', "Şifalı otlardan yapılan acımsı siyah jöle 'guilinggao', sıcak günlerin ferahlatıcısıdır.", "The bitter black herbal jelly 'guilinggao' is a cooling treat on hot days."),
  ('dragonmother', 'Ejderha Ana Tapınağı', 'Dragon Mother Temple', "Nehir tanrıçası Ejderha Ana'ya adanan tapınak, nehir halkının asırlık inancıdır.", "Dedicated to the river goddess Dragon Mother, the temple is the river folk's age-old faith.")],
 'beihai': [
  ('silverbeach', 'Gümüş Kumsal', 'Silver Beach', "Pırıl pırıl ince kumuyla 'göğün altındaki birinci plaj', kilometrelerce uzanır.", "With glittering fine sand, 'the number-one beach under heaven' stretches for miles."),
  ('pearl', 'İnci Şehri', 'Pearl City', "Hepu'nun Güney Denizi incileri, imparatorluk haraçlarından beri en kıymetlisi sayılır.", "Hepu's South Sea pearls have been prized as the finest since imperial tribute days."),
  ('weizhou', 'Weizhou Adası', 'Weizhou Island', "Çin'in en genç volkanik adası, kara kayalıkları ve mercanlarıyla dalgıçları çeker.", "China's youngest volcanic island draws divers with black cliffs and coral."),
  ('oldstreet', 'Eski Sokak', 'Old Street', "Yüz yıllık sömürge revaklı binalar, Deniz İpek Yolu limanının geçmişini yaşatır.", "Century-old colonnaded colonial buildings keep alive the past of the Maritime Silk Road port.")],
 'qinzhou': [
  ('nixingpottery', 'Nixing Çömleği', 'Nixing Pottery', "Fırında kendiliğinden renk değiştiren Nixing çömlekçiliği, Çin'in dört ünlü çömleğindendir.", "Nixing pottery, which changes colour by itself in the kiln, is one of China's four famous wares."),
  ('dolphin', 'Beyaz Yunus', 'White Dolphin', "Sanniang Körfezi'nde yüzen nadir Çin beyaz yunusları, şehrin sevimli simgesidir.", "Rare Chinese white dolphins swimming in Sanniang Bay are the city's beloved emblem."),
  ('oysterfarm', 'İstiridye Diyarı', 'Oyster Land', "Sığ koylarda yetiştirilen dev istiridyeler, Qinzhou'yu Çin'in istiridye başkenti yapar.", "Giant oysters farmed in shallow bays make Qinzhou China's oyster capital."),
  ('general', 'General Feng Zicai', 'General Feng Zicai', "Sınırı savunan yaşlı general Feng Zicai'nin memleketi, kahramanlık anılarıyla doludur.", "Hometown of the aged general Feng Zicai who defended the frontier, it is full of heroic memory.")],
 'guigang': [
  ('lotus', 'Nilüfer Şehri', 'Lotus City', "Yaz boyu açan dev nilüfer tarlalarıyla Guigang, 'nilüfer şehri' diye anılır.", "With vast lotus fields blooming all summer, Guigang is called the 'lotus city'."),
  ('uprising', 'Jintian Ayaklanması', 'Jintian Uprising', "Tarihi sarsan Taiping Ayaklanması'nın ilk kıvılcımı bu topraklarda çakıldı.", "The first spark of the history-shaking Taiping Uprising was struck on these lands."),
  ('nanshan', 'Nanshan Tapınağı', 'Nanshan Temple', "Kayaya oyulmuş bin yıllık mağara tapınağı, imparator yazıtlarıyla bezelidir.", "The thousand-year cave temple carved into the rock is adorned with imperial inscriptions."),
  ('sugarcane', 'Şeker Kamışı', 'Sugarcane', "Verimli nehir ovası, Çin'in en büyük şeker üretiminin tatlı kaynağıdır.", "The fertile river plain is the sweet source of China's largest sugar production.")],
 'yulin': [
  ('medicine', 'Şifalı Ot Pazarı', 'Herbal Medicine Market', "Güney Çin'in en büyük geleneksel ilaç pazarı, binlerce şifalı bitkiyi bir araya getirir.", "Southern China's largest traditional-medicine market gathers thousands of healing herbs."),
  ('goldenpalace', 'Yuntian Sarayı', 'Yuntian Palace', "Altın kaplı dev kültür sarayı, görkemli heykelleri ve salonlarıyla şaşırtır.", "The gold-clad giant cultural palace astonishes with grand statues and halls."),
  ('lychee', 'Liçi Bahçeleri', 'Lychee Groves', "Sıcak tepelerde yetişen tatlı liçi, yaz pazarlarının kırmızı hazinesidir.", "Sweet lychees grown on warm hills are the red treasure of summer markets."),
  ('beef', 'Yulin Sığır Eti', 'Yulin Beef', "Baharatla kurutulan 'niuba' sığır eti, bölgenin asırlık imza atıştırmalığıdır.", "Spice-cured 'niuba' beef is the region's age-old signature snack.")],
 'baise': [
  ('redbase', 'Baise Ayaklanması', 'Baise Uprising', "Genç Deng Xiaoping'in yönettiği ayaklanma, kızıl tarihin önemli bir dönüm noktasıdır.", "The uprising led by a young Deng Xiaoping is a key turning point in red history."),
  ('sinkhole', 'Leye Obrukları', 'Leye Sinkholes', "Dünyanın en büyük dev obruk kümesi, derinliklerinde gizli ormanlar barındırır.", "The world's largest cluster of giant sinkholes hides forests in its depths."),
  ('mango', 'Mango Başkenti', 'Mango Capital', "Sıcak vadileriyle Baise, Çin'in en büyük mango bahçelerine ev sahipliği yapar.", "With its hot valleys, Baise hosts China's largest mango groves."),
  ('aluminum', 'Alüminyum Şehri', 'Aluminium City', "Zengin boksit yataklarıyla şehir, Çin'in alüminyum sanayisinin güney üssüdür.", "Rich in bauxite, the city is the southern base of China's aluminium industry.")],
 'hechi': [
  ('longevity', 'Bama Uzun Ömür Diyarı', 'Bama Longevity', "Yüz yaşını aşan sakinleriyle Bama, dünyanın ünlü 'uzun ömür memleketi'dir.", "With residents past a hundred years, Bama is a world-famous 'home of longevity'."),
  ('folksong', 'Liu Sanjie', 'Liu Sanjie', "Türkü perisi Liu Sanjie'nin efsanesi, karşılıklı şarkı atışmalarında yaşar.", "The legend of the song fairy Liu Sanjie lives on in antiphonal singing contests."),
  ('bronzedrum', 'Tunç Davul', 'Bronze Drum', "Zhuang ve dağ halklarının kutsal tunç davulları, en yoğun şekilde burada toplanır.", "The sacred bronze drums of the Zhuang and mountain peoples are most densely gathered here."),
  ('geopark', 'Karst Jeoparkı', 'Karst Geopark', "Obrukları, mağaraları ve yer altı nehirleriyle bölge, bir karst harikalar diyarıdır.", "With sinkholes, caves and underground rivers, the region is a karst wonderland.")],
 'laibin': [
  ('sugarcity', 'Şeker Başkenti', 'Sugar Capital', "Uçsuz şeker kamışı tarlalarıyla Laibin, 'Çin'in şeker şehri' diye anılır.", "With endless cane fields, Laibin is called 'China's sugar city'."),
  ('yao', 'Dayao Dağı Yao', 'Dayao Yao People', "Jinxiu'nun Dayao dağlarında yaşayan Yao halkı, beş ayrı boyuyla kültür hazinesidir.", "The Yao of Jinxiu's Dayao mountains, in five distinct branches, are a cultural treasure."),
  ('hongshui', 'Kızıl Su Nehri', 'Hongshui River', "Vadileri yaran güçlü Kızıl Su Nehri, barajları ve manzaralarıyla bölgeyi besler.", "The mighty Hongshui River carving the valleys feeds the region with dams and views."),
  ('shengtang', 'Shengtang Dağı', 'Mount Shengtang', "Bulut denizi ve şelaleleriyle dağ, Dayao sıradağlarının en yüksek zirvesidir.", "With a sea of clouds and waterfalls, the mountain is the highest peak of the Dayao range.")],
 'chongzuo': [
  ('waterfall', 'Detian Şelalesi', 'Detian Falls', "Vietnam sınırındaki Detian, Asya'nın en büyük ülkeler arası şelalesidir.", "On the Vietnam border, Detian is Asia's largest transnational waterfall."),
  ('langur', 'Beyaz Başlı Langur', 'White-Headed Langur', "Yalnızca bu kireçtaşı tepelerde yaşayan nadir beyaz başlı langur, dünyanın en ender maymunlarındandır.", "Living only in these limestone hills, the rare white-headed langur is among the world's most endangered monkeys."),
  ('rockart', 'Huashan Kaya Resimleri', 'Huashan Rock Art', "Zuojiang kayalıklarına 2.000 yıl önce çizilen kızıl figürler UNESCO mirasıdır.", "Red figures painted on the Zuojiang cliffs 2,000 years ago are UNESCO-listed."),
  ('borderpass', 'Dostluk Geçidi', 'Friendship Pass', "Vietnam'a açılan tarihî sınır kapısı, güney İpek Yolu'nun kara kapısıdır.", "The historic border gate to Vietnam is the land gate of the southern Silk Road.")],
}


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def main():
    p = os.path.join(ROOT, "lib", "core", "constants", "cities.dart")
    src = open(p, encoding="utf-8").read()
    if "'sanming': [" in src:
        print("cities.dart already contains sanming — skipped")
        return
    out = []
    for slug, lms in C.items():
        out.append(f"  '{slug}': [")
        for (icon, nt, ne, dt, de) in lms:
            out.append(
                f"    Landmark(icon: '{icon}', photo: '{icon}', nameTr: '{esc(nt)}', "
                f"nameEn: '{esc(ne)}', descTr: '{esc(dt)}', descEn: '{esc(de)}'),")
        out.append("  ],")
    dart = "\n".join(out) + "\n"
    marker = "  'beijing': ["
    assert marker in src, "beijing marker not found"
    src = src.replace(marker, dart + marker, 1)
    open(p, "w", encoding="utf-8").write(src)
    n = sum(len(v) for v in C.values())
    print(f"cities.dart updated with {len(C)} L5 cities ({n} landmarks)")


if __name__ == "__main__":
    main()
