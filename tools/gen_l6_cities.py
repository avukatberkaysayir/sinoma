# Injects the HSK-6 (Level 6) unit-city Landmark data into cities.dart (24 new
# cities, 96 landmarks). Icon art comes from tools/fetch_all_icons.py
# (globally-unique icons8 set). After: extend fetch_all_icons.py, regenerate packs.
import os, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

C = {
 'zunyi': [
  ('huiyi', 'Zunyi Konferansı', 'Zunyi Conference', "1935'te devrimin kaderini değiştiren toplantının yapıldığı ev, kızıl tarihin dönüm noktasıdır.", "The house of the 1935 meeting that changed the revolution's fate is a turning point of red history."),
  ('moutai', 'Moutai Kasabası', 'Moutai Town', "Chishui kıyısındaki kasabada damıtılan Moutai, Çin'in ulusal içkisi sayılan efsanevi baijiu'dur.", "Distilled in the town on the Chishui banks, Moutai is the legendary baijiu hailed as China's national drink."),
  ('loushan', 'Loushan Geçidi', 'Loushan Pass', "Dağları yaran sarp geçit, Mao'nun ünlü şiirine konu olan tarihi muharebenin sahnesidir.", "The steep pass cutting the mountains is the scene of the historic battle immortalised in Mao's famous poem."),
  ('chishui', 'Chishui Şelaleleri', 'Chishui Falls', "Kızıl Danxia kayalıklarından dökülen şelaleler ve bambu ormanları, 'kızıl nehir' vadisini doldurur.", "Waterfalls pouring off red Danxia cliffs and bamboo groves fill the 'red river' valley.")],
 'liupanshui': [
  ('coolcity', 'Serin Şehir', 'Cool City', "Yazın 19 dereceyi geçmeyen havasıyla Liupanshui, 'Çin'in serin başkenti' diye anılır.", "With summers that rarely pass 19°C, Liupanshui is called 'China's cool capital'."),
  ('coal', 'Güneybatının Kömür Denizi', 'Coal Sea of the Southwest', "Zengin kömür damarlarıyla şehir, güneybatı Çin'in enerji ocağıdır.", "Rich coal seams make the city the energy hearth of southwest China."),
  ('grassland', 'Wumeng Çayırları', 'Wumeng Grasslands', "Bulutlara komşu Wumeng platosunun uçsuz çayırları, at sürüleri ve rüzgâr gülleriyle bezelidir.", "The endless highland meadows of the Wumeng plateau are dotted with horse herds and wind turbines."),
  ('kiwi', 'Kırmızı Özlü Kivi', 'Red-Heart Kiwifruit', "Serin yaylalarda yetişen kırmızı özlü kivi, şehrin tatlı yeşil hazinesidir.", "Red-heart kiwifruit grown on the cool highlands is the city's sweet green treasure.")],
 'anshun': [
  ('huangguoshu', 'Huangguoshu Şelalesi', 'Huangguoshu Waterfall', "Asya'nın en büyük şelalesi, gökkuşağı saçan sis bulutuyla 77 metreden gürler.", "Asia's largest waterfall thunders down 77 metres, its mist scattering rainbows."),
  ('dixi', 'Dixi Yer Operası', 'Dixi Ground Opera', "Ahşap savaşçı maskeleriyle köy meydanlarında oynanan Dixi, 'Çin operasının yaşayan fosili'dir.", "Performed in village squares with wooden warrior masks, Dixi is the 'living fossil of Chinese opera'."),
  ('batik', 'Batik Sanatı', 'Batik Art', "Buyi ve Miao kadınlarının balmumuyla çizip çivit mavisine boyadığı kumaşlar, Anshun'un imzasıdır.", "Cloth drawn with wax and dyed indigo by Buyi and Miao women is Anshun's signature craft."),
  ('tunpu', 'Tunpu Köyleri', 'Tunpu Villages', "Ming ordusunun taş garnizon köylerinde yaşayanlar, 600 yıllık kıyafet ve lehçeyi bugün de sürdürür.", "Villagers of the Ming army's stone garrison towns still keep 600-year-old dress and dialect alive.")],
 'bijie': [
  ('azalea', 'Yüz Li Açelya Kuşağı', 'Hundred-Li Azalea Belt', "Her bahar dağ sırtlarını kaplayan açelya denizi, dünyanın en büyük doğal çiçek bahçesidir.", "The sea of azaleas blanketing the ridges each spring is the world's largest natural flower garden."),
  ('zhijin', 'Zhijin Mağarası', 'Zhijin Cave', "Dev sarkıt ormanlarıyla 'yeraltı sarayı' Zhijin, Çin'in en görkemli mağarasıdır.", "With forests of giant stalagmites, the 'underground palace' of Zhijin is China's most spectacular cave."),
  ('caohai', 'Caohai Gölü Turnaları', 'Caohai Cranes', "Weining'deki sığ göl, her kış nadir kara boyunlu turnaların kışlağı olur.", "The shallow lake at Weining becomes the winter home of rare black-necked cranes."),
  ('potato', 'Patates Başkenti', 'Potato Capital', "Serin yaylaların patatesi Bijie'yi Çin'in patates ambarı yapar; Weining patatesi ülkece ünlüdür.", "Highland potatoes make Bijie China's potato barn; Weining spuds are famous nationwide.")],
 'qujing': [
  ('rapeseed', 'Luoping Kolza Denizi', 'Luoping Canola Sea', "Her şubat Luoping ovasını kaplayan altın sarısı kolza tarlaları, arıcıları ve fotoğrafçıları çeker.", "Each February the golden canola fields of Luoping draw beekeepers and photographers alike."),
  ('ham', 'Xuanwei Jambonu', 'Xuanwei Ham', "Asırlardır tuzlanıp kurutulan Xuanwei jambonu, Yunnan sofrasının gurur kaynağıdır.", "Salt-cured for centuries, Xuanwei ham is the pride of the Yunnan table."),
  ('jiulong', 'Jiulong Şelaleleri', 'Jiulong Waterfalls', "'Dokuz Ejder' nehrinin basamak basamak dökülen on şelalesi, Çin'in en güzel şelale dizisidir.", "The ten stepped cascades of the 'Nine Dragons' river form China's most beautiful waterfall chain."),
  ('sandforest', 'Renkli Kum Ormanı', 'Colourful Sand Forest', "Rüzgârın yonttuğu rengârenk kum sütunları, Luliang'da doğal bir heykel bahçesi kurar.", "Wind-carved columns of coloured sand form a natural sculpture garden at Luliang.")],
 'yuxi': [
  ('fuxian', 'Fuxian Gölü', 'Fuxian Lake', "Çin'in en derin ikinci gölü, kristal berraklığındaki suyuyla bir dağ aynasıdır.", "China's second-deepest lake is a mountain mirror of crystal-clear water."),
  ('nieer', 'Besteci Nie Er', 'Composer Nie Er', "Ulusal marşın bestecisi Nie Er'in memleketi, onu müzik parkı ve anıtıyla onurlandırır.", "Hometown of Nie Er, composer of the national anthem, the city honours him with a music park and memorial."),
  ('chengjiang', 'Chengjiang Fosilleri', 'Chengjiang Fossils', "530 milyon yıllık Kambriyen fosil yatakları, hayvan yaşamının şafağını gösteren UNESCO mirasıdır.", "The 530-million-year-old Cambrian fossil beds are a UNESCO site showing the dawn of animal life."),
  ('kiln', 'Yuxi Fırını', 'Yuxi Kiln', "Yuan döneminden kalma antik fırın, Yunnan'ın mavi-beyaz seramiğinin doğduğu yerdir.", "The ancient Yuan-era kiln is the birthplace of Yunnan's blue-and-white ceramics.")],
 'dali': [
  ('threepagodas', 'Üç Pagoda', 'Three Pagodas', "Bin yıldır Cangshan eteklerinde yükselen üç zarif pagoda, antik Dali krallığının simgesidir.", "Rising at the foot of Cangshan for a thousand years, the three graceful pagodas are the emblem of the ancient Dali kingdom."),
  ('erhai', 'Erhai Gölü', 'Erhai Lake', "Kulak biçimli dağ gölü Erhai, balıkçı sandalları ve göl kıyısı köyleriyle bir tablo gibidir.", "The ear-shaped mountain lake of Erhai is a painting of fishing boats and lakeside villages."),
  ('cangshan', 'Cangshan Dağları', 'Cangshan Mountains', "On dokuz zirvesi karla kaplı Cangshan, Dali'nin ardında yeşil bir perde gibi yükselir.", "With nineteen snow-capped peaks, Cangshan rises like a green curtain behind Dali."),
  ('wind', 'Rüzgâr, Çiçek, Kar, Ay', 'Wind, Flower, Snow, Moon', "Xiaguan rüzgârı, Shangguan çiçeği, Cangshan karı ve Erhai ayı — Dali'nin dört güzelliği bir şiirdir.", "Xiaguan wind, Shangguan flowers, Cangshan snow and the Erhai moon — Dali's four beauties read like a poem.")],
 'lijiang': [
  ('oldtown', 'Lijiang Eski Şehri', 'Lijiang Old Town', "Kanallar ve kiremit çatılı ahşap evlerle örülü UNESCO şehri, Naxi kültürünün yaşayan kalbidir.", "Woven of canals and tile-roofed timber houses, the UNESCO town is the living heart of Naxi culture."),
  ('snowmountain', 'Yeşim Ejder Karlı Dağı', 'Jade Dragon Snow Mountain', "5.596 metrelik buzullu zirve, şehrin üzerinde uyuyan bir yeşim ejder gibi parlar.", "The 5,596-metre glaciated peak gleams over the town like a sleeping jade dragon."),
  ('dongba', 'Dongba Yazısı', 'Dongba Script', "Naxi rahiplerinin resim-yazısı Dongba, dünyada hâlâ yaşayan tek piktografik yazıdır.", "The Naxi priests' picture-writing, Dongba, is the world's last living pictographic script."),
  ('tigerleaping', 'Kaplan Atlayan Geçidi', 'Tiger Leaping Gorge', "Efsaneye göre bir kaplanın tek sıçrayışta aştığı geçit, dünyanın en derin kanyonlarındandır.", "The gorge a tiger is said to have cleared in one leap is among the deepest canyons on earth.")],
 'lincang': [
  ('dianhong', 'Dianhong Çayı', 'Dianhong Black Tea', "Fengqing'in altın tomurcuklu kızıl çayı Dianhong, dünyaya Yunnan'ın adını duyurdu.", "Fengqing's golden-bud black tea, Dianhong, carried Yunnan's name to the world."),
  ('wadrum', 'Va Ahşap Davulu', 'Wa Wooden Drum', "Va halkının kutsal ahşap davulları, dağ köylerinde saç savuran davul dansıyla gümbürder.", "The sacred wooden drums of the Wa people thunder through hill villages in the hair-swinging drum dance."),
  ('teatrees', 'Antik Çay Ağaçları', 'Ancient Tea Trees', "Binlerce yıllık yabani çay ağaçlarının anavatanı Lincang, çayın doğduğu ormanları saklar.", "Home to wild tea trees thousands of years old, Lincang guards the forests where tea was born."),
  ('lancang', 'Lancang Nehri', 'Lancang River', "Mekong'un yukarı kolu Lancang, dev barajlarıyla vadileri aydınlatarak güneye akar.", "The upper Mekong, the Lancang flows south, lighting the valleys with its giant dams.")],
 'puer': [
  ('tea', "Pu'er Çayı", "Pu'er Tea", "Yıllandıkça olgunlaşan preslenmiş Pu'er çayı, adını bu dağ şehrinden alan yaşayan bir hazinedir.", "Pressed Pu'er tea, mellowing as it ages, is a living treasure named after this mountain city."),
  ('coffee', "Çin'in Kahve Başkenti", "China's Coffee Capital", "Çin kahvesinin yarıdan fazlası Pu'er'in sisli yamaçlarında yetişir; şehir latte kokar.", "More than half of China's coffee grows on Pu'er's misty slopes; the city smells of lattes."),
  ('teahorse', 'Çay-At Yolu', 'Tea Horse Road', "Katır kervanlarının çayı Tibet'e taşıdığı antik yol, Pu'er'den başlayıp bulutlara tırmanırdı.", "The ancient road where mule caravans carried tea to Tibet began at Pu'er and climbed into the clouds."),
  ('peafowl', 'Yeşil Tavus Kuşu', 'Green Peafowl', "Nadir yeşil tavus kuşunun son sığınaklarından olan tropik ormanlar, şehrin yaban tacıdır.", "Tropical forests sheltering the rare green peafowl are the city's wild crown.")],
 'baoshan': [
  ('volcano', 'Tengchong Volkanları', 'Tengchong Volcanoes', "Doksan yedi sönmüş volkan konisi, Tengchong ovasını ay yüzeyine çevirir.", "Ninety-seven dormant volcanic cones turn the Tengchong plain into a lunar landscape."),
  ('rehai', 'Rehai Kaplıcaları', 'Rehai Hot Sea', "Kaynayan 'Sıcak Deniz' vadisinde gayzerler tüter; yumurtalar kaynak sularında pişer.", "In the boiling 'Hot Sea' valley geysers steam and eggs cook in the spring pools."),
  ('heshun', 'Heshun Kasabası', 'Heshun Town', "Yurtdışına açılan tüccarların taş kasabası Heshun, Çin'in en eski köy kütüphanesini barındırır.", "Heshun, stone town of merchants who ventured abroad, keeps China's oldest village library."),
  ('gaoligong', 'Gaoligong Dağları', 'Gaoligong Mountains', "Kelebek vadileri ve sıcak ormanlarıyla Gaoligong, bir canlı türleri hazinesidir.", "With butterfly valleys and warm forests, Gaoligong is a treasure house of species.")],
 'deyang': [
  ('sanxingdui', 'Sanxingdui Kalıntıları', 'Sanxingdui Ruins', "Fırlak gözlü dev bronz maskeler, 3.000 yıllık gizemli Shu uygarlığını gün ışığına çıkardı.", "Giant bronze masks with bulging eyes brought the mysterious 3,000-year-old Shu civilisation to light."),
  ('jiannanchun', 'Jiannanchun Likörü', 'Jiannanchun Liquor', "Tang sarayına sunulan Mianzhu baijiu'su Jiannanchun, bin beş yüz yıldır damıtılır.", "Jiannanchun, the Mianzhu baijiu once served at the Tang court, has been distilled for fifteen centuries."),
  ('nianhua', 'Mianzhu Yılbaşı Baskıları', 'Mianzhu New Year Prints', "El boyaması tahta baskı yılbaşı resimleri, kapılara bereket ve renk asar.", "Hand-painted woodblock New Year pictures hang fortune and colour on doorways."),
  ('turbine', 'Ağır Sanayi Başkenti', 'Heavy Industry Capital', "Ülkenin dev türbin ve jeneratörlerinin çoğu Deyang'ın atölyelerinde dövülür.", "Most of the nation's giant turbines and generators are forged in Deyang's workshops.")],
 'mianyang': [
  ('libai', "Li Bai'nin Memleketi", "Li Bai's Hometown", "Şairlerin ölümsüzü Li Bai, Jiangyou'nun dağları arasında büyüdü; dizeleri hâlâ burada yankılanır.", "Li Bai, the immortal of poets, grew up among Jiangyou's mountains; his verses still echo here."),
  ('sciencecity', 'Bilim Şehri', 'Science City', "Çin'in tek 'Bilim ve Teknoloji Şehri' unvanlı kenti, laboratuvarları ve ekranlarıyla geleceği kurar.", "China's only city titled 'Science and Technology City' builds the future with labs and screens."),
  ('qiang', 'Qiang Taş Kuleleri', 'Qiang Stone Towers', "Beichuan'ın dağ köylerinde Qiang halkının taş gözetleme kuleleri asırlardır ayaktadır.", "In Beichuan's mountain villages the stone watchtowers of the Qiang people have stood for centuries."),
  ('mifen', 'Mianyang Pirinç Şehriyesi', 'Mianyang Rice Noodles', "İnce pirinç şehriyesi, sabahları tavuk ve sakatat suyuyla buharlanan şehrin uyanışıdır.", "Fine rice noodles steaming in chicken and offal broth are how the city wakes each morning.")],
 'nanchong': [
  ('langzhong', 'Langzhong Antik Şehri', 'Langzhong Ancient City', "Feng shui'ye göre kurulmuş en iyi korunan antik şehir, nehir kıvrımının kucağında uyur.", "The best-preserved ancient city laid out by feng shui sleeps in the embrace of a river bend."),
  ('silk', 'İpek Başkenti', 'Silk Capital', "İki bin yıllık dokuma geleneğiyle Nanchong, Çin'in batıdaki ipek başkentidir.", "With two thousand years of weaving, Nanchong is China's silk capital of the west."),
  ('zhangfei', 'Zhang Fei Sığır Eti', 'Zhang Fei Beef', "Üç Krallık kahramanı Zhang Fei'nin şehrinde kurutulan baharatlı sığır eti, onun adını taşır.", "Spiced cured beef from the city of Three Kingdoms hero Zhang Fei bears his name."),
  ('zhude', "Zhu De'nin Memleketi", "Zhu De's Hometown", "Mareşal Zhu De'nin Yilong'daki mütevazı evi, modern tarihin hac duraklarındandır.", "Marshal Zhu De's modest home in Yilong is a pilgrimage stop of modern history.")],
 'yibin': [
  ('wuliangye', 'Wuliangye Likörü', 'Wuliangye Liquor', "Beş tahıldan damıtılan Wuliangye, Çin'in en değerli baijiu markalarındandır.", "Distilled from five grains, Wuliangye is among China's most prized baijiu brands."),
  ('firstcity', "Yangtze'nin İlk Şehri", 'First City on the Yangtze', "Min ve Jinsha nehirlerinin kavuştuğu yerde Yangtze doğar; Yibin bu yüzden 'ilk şehir'dir.", "Where the Min and Jinsha rivers meet, the Yangtze is born; hence Yibin is its 'first city'."),
  ('bamboosea', 'Shunan Bambu Denizi', 'Shunan Bamboo Sea', "Yüz yirmi tepeyi örten bambu okyanusu, rüzgârda dalgalanan yeşil bir denizdir.", "An ocean of bamboo cloaking a hundred and twenty hills sways like a green sea in the wind."),
  ('ranmian', 'Alevli Erişte', 'Burning Noodles', "Yağıyla tutuşturulabilecek kadar susuz yoğrulan 'ranmian', Yibin kahvaltısının acılı yıldızıdır.", "Kneaded so dry its oil can catch flame, 'ranmian' is the fiery star of a Yibin breakfast.")],
 'luzhou': [
  ('laojiao', 'Laojiao Mahzenleri', 'Laojiao Cellars', "1573'ten beri kesintisiz kullanılan çamur fermantasyon çukurları, kokulu baijiu'nun kalbidir.", "Mud fermentation pits in continuous use since 1573 are the heart of fragrant baijiu."),
  ('port', 'Yangtze Limanı', 'Yangtze Port', "İki nehrin kavşağındaki liman şehri, Sichuan'ın denize açılan su kapısıdır.", "The port city at the meeting of two rivers is Sichuan's water gate to the sea."),
  ('longan', 'Longan Bahçeleri', 'Longan Orchards', "Nehir vadilerinin sıcak yamaçlarında yetişen longan, 'ejder gözü' denen bal tatlı meyvedir.", "Grown on warm river slopes, longan is the honey-sweet fruit called 'dragon's eye'."),
  ('umbrella', 'Yağlı Kağıt Şemsiyeler', 'Oil-Paper Umbrellas', "Fenshui ustalarının el yapımı yağlı kağıt şemsiyeleri, dört yüz yıllık zarif bir zanaattır.", "Handmade oil-paper umbrellas of Fenshui masters are a graceful four-hundred-year craft.")],
 'leshan': [
  ('giantbuddha', 'Leshan Dev Budası', 'Leshan Giant Buddha', "Kayaya oyulmuş 71 metrelik oturan Buda, bin iki yüz yıldır nehirlerin kavşağını izler.", "Carved into the cliff, the 71-metre seated Buddha has watched the river junction for twelve centuries."),
  ('emei', 'Emei Dağı', 'Mount Emei', "Budizmin dört kutsal dağından Emei'nin Altın Zirvesi, bulut denizinin üstünde parlar.", "Golden Summit of Emei, one of Buddhism's four sacred mountains, shines above a sea of clouds."),
  ('monkeys', 'Emei Makakları', 'Emei Macaques', "Dağ patikalarının haylaz makakları, hacıların çantalarını arsızca yoklamalarıyla ünlüdür.", "The mischievous macaques of the mountain paths are famous for boldly frisking pilgrims' bags."),
  ('qiaojiao', 'Qiaojiao Sığır Çorbası', 'Qiaojiao Beef Soup', "Şifalı otlarla kaynayan sığır çorbası 'qiaojiao', Leshan sokak sofralarının yüz yıllık klasiğidir.", "Beef soup simmered with herbs, 'qiaojiao' is the century-old classic of Leshan street tables.")],
 'zigong': [
  ('saltwell', 'Bin Metrelik Tuz Kuyuları', 'Kilometre-Deep Salt Wells', "Dünyada bin metreyi ilk aşan Shenhai kuyusu, iki bin yıllık tuz şehrinin zaferidir.", "The Shenhai well, first on earth past a thousand metres, is the triumph of the two-thousand-year salt city."),
  ('lantern', 'Zigong Fener Festivali', 'Zigong Lantern Festival', "Devasa ışıklı fener bahçeleri, her yeni yılda şehri bir masal diyarına çevirir.", "Gardens of colossal glowing lanterns turn the city into a fairyland every new year."),
  ('dinosaur', 'Dinozor Müzesi', 'Dinosaur Museum', "Jura katmanlarından fışkıran binlerce fosil, Zigong'u Çin'in dinozor başkenti yapar.", "Thousands of fossils erupting from Jurassic beds make Zigong China's dinosaur capital."),
  ('rabbit', 'Soğuk Tavşan', 'Cold Rabbit', "Acılı soğuk servis edilen 'lengtu' tavşanı, Sichuan'ın en cesur mezesinin memleketi buradadır.", "Spicy cold-served 'lengtu' rabbit calls this city home — Sichuan's boldest appetiser.")],
 'panzhihua': [
  ('steel', 'Vanadyum-Titanyum Başkenti', 'Vanadium-Titanium Capital', "Dağların içine kurulmuş dev çelik kenti, dünyanın en zengin vanadyum-titanyum yataklarını işler.", "The giant steel city built into the mountains works the world's richest vanadium-titanium deposits."),
  ('fruitvalley', 'Güneş Meyveleri Vadisi', 'Sunny Fruit Valley', "Kurak-sıcak vadinin mangoları ve narları, kışın bile güneşle olgunlaşır.", "Mangoes and pomegranates of the dry-hot valley ripen in sunshine even in winter."),
  ('sunshine', 'Kış Güneşi Şehri', 'Winter Sun City', "Yılda 2.700 saat güneşiyle Panzhihua, kışı ılık geçirmek isteyenlerin sağlık durağıdır.", "With 2,700 hours of sun a year, Panzhihua is the wellness stop for a mild winter."),
  ('jinsha', 'Jinsha Nehri', 'Jinsha River', "Altın kumlu Jinsha, derin vadileri yararak şehrin ortasından coşkuyla akar.", "The golden-sanded Jinsha surges through the city, carving its deep valleys.")],
 'dazhou': [
  ('gas', 'Doğalgaz Başkenti', 'Natural Gas Capital', "Puguang dev gaz sahası, Dazhou'yu Çin'in doğalgaz enerji üssü yapar.", "The giant Puguang field makes Dazhou China's natural-gas energy base."),
  ('ba', 'Ba Krallığı Mirası', 'Ba Kingdom Legacy', "Söğüt yaprağı kılıçlarıyla antik Ba savaşçılarının toprakları, Luojiaba kalıntılarında konuşur.", "The land of ancient Ba warriors with willow-leaf swords speaks through the Luojiaba ruins."),
  ('dengying', 'Lamba Gölgesi Sığır Eti', 'Lamp-Shadow Beef', "Işığı geçirecek kadar ince kesilen baharatlı 'dengying' eti, adını gölge oyunundan alır.", "Sliced thin enough to glow against light, spicy 'dengying' beef takes its name from shadow plays."),
  ('hanque', 'Han Taş Kapıları', 'Han Stone Gate-Towers', "Quxian'daki iki bin yıllık taş 'que' kuleleri, Han mimarisinin ayakta kalan zarafetidir.", "The two-thousand-year-old stone 'que' towers at Quxian are the surviving grace of Han architecture.")],
 'guangyuan': [
  ('jianmen', 'Jianmen Geçidi', 'Jianmen Pass', "'Bir kişi tutsa on bin kişi geçemez' denen kılıç dağı geçidi, Shu yolunun kilididir.", "The sword-mountain pass where 'one man can hold off ten thousand' is the lock of the Shu road."),
  ('wuzetian', "Wu Zetian'ın Doğduğu Şehir", "Wu Zetian's Birthplace", "Çin'in tek kadın imparatoru Wu Zetian burada doğdu; Huangze Tapınağı onu bin yıldır anar.", "China's only woman emperor, Wu Zetian, was born here; the Huangze Temple has honoured her for a millennium."),
  ('plankroad', 'Antik Tahta Yollar', 'Ancient Plank Roads', "Uçurumlara çakılmış tahta yollar, 'göğe çıkmaktan zor' Shu yolunun cesaret anıtıdır.", "Plank roads nailed to sheer cliffs are the monument of daring on the Shu road 'harder than climbing to heaven'."),
  ('cypress', 'Cuiyun Servi Koridoru', 'Cuiyun Cypress Corridor', "Üç Krallık'tan kalma on binlerce antik servi, antik yolu yeşil bir tünele çevirir.", "Tens of thousands of ancient cypresses from the Three Kingdoms era turn the old road into a green tunnel.")],
 'yaan': [
  ('panda', 'Pandanın Anavatanı', 'Cradle of the Panda', "Dev panda bilime ilk kez 1869'da Baoxing'de tanıtıldı; Bifengxia üssü bu mirası yaşatır.", "The giant panda was first described for science at Baoxing in 1869; the Bifengxia base keeps that legacy alive."),
  ('rain', 'Yağmur Şehri', 'Rain City', "'Ya yağmuru' neredeyse her gece çatıları yıkar; şehir yeşilin bin tonuyla parlar.", "The 'Ya rain' washes the rooftops almost nightly; the city gleams in a thousand greens."),
  ('mengding', 'Mengding Dağı Çayı', 'Mount Mengding Tea', "İnsan eliyle çay ilk kez iki bin yıl önce Mengding'de dikildi; dağ, çay kültürünün beşiğidir.", "Tea was first planted by human hands on Mengding two thousand years ago; the mountain is the cradle of tea culture."),
  ('yayu', 'Ya Balığı', 'Ya Fish', "Kar sularında yetişen efsanevi Ya balığı, kaynayan güveçlerde şehrin sofra gururudur.", "The fabled Ya fish of snow-fed streams is the city's pride, served in bubbling casseroles.")],
 'xianyang': [
  ('qincapital', 'Qin İmparatorluk Başkenti', 'Qin Imperial Capital', "Çin'i ilk birleştiren Qin hanedanının başkenti burasıydı; imparatorluğun yolu Xianyang'dan geçti.", "Here stood the capital of the Qin, first unifiers of China; the road to empire ran through Xianyang."),
  ('qianling', 'Qianling Anıtmezarı', 'Qianling Mausoleum', "Wu Zetian ile eşinin dağa oyulan ortak mezarı, yazısız dikilitaşıyla tarihe meydan okur.", "The mountain tomb shared by Wu Zetian and her husband defies history with its blank stele."),
  ('zhengguo', 'Zhengguo Kanalı', 'Zhengguo Canal', "İki bin yıllık sulama kanalı, Guanzhong ovasını Qin'in tahıl ambarına çevirdi.", "The two-thousand-year-old irrigation canal turned the Guanzhong plain into the granary of Qin."),
  ('guokui', 'Guokui Gözlemesi', 'Guokui Flatbread', "Kazan kapağı kadar büyük ve çıtır 'guokui' ekmeği, Shaanxi sofrasının asırlık atıştırmalığıdır.", "Crisp 'guokui' flatbread, big as a pot lid, is the centuries-old snack of the Shaanxi table.")],
 'baoji': [
  ('bronze', 'Bronz Eserler Başkenti', 'Bronze Ware Capital', "'Çin' adının bilinen ilk yazımını taşıyan He zun dahil binlerce Zhou bronzu, Baoji'de gün yüzüne çıktı.", "Thousands of Zhou bronzes, including the He zun bearing the first known writing of the name 'China', surfaced at Baoji."),
  ('famen', 'Famen Tapınağı', 'Famen Temple', "Buda'nın parmak kemiği kalıntısını saklayan Famen, Tang imparatorlarının kutsal hazinesiydi.", "Guarding the finger-bone relic of the Buddha, Famen was the sacred treasury of Tang emperors."),
  ('taibai', 'Taibai Dağı', 'Mount Taibai', "Qinling'in 3.771 metrelik çatısı Taibai, yazın bile karlı zirvesiyle efsanelere konu olur.", "Taibai, the 3,771-metre roof of the Qinling, feeds legends with a summit snowy even in summer."),
  ('saozi', 'Saozi Eriştesi', 'Saozi Noodles', "Ekşi-acı et soslu Qishan 'saozi' eriştesi, üç bin yıllık Zhou mutfağının yaşayan tadıdır.", "Qishan 'saozi' noodles in sour-spicy meat sauce are the living taste of three-thousand-year-old Zhou cooking.")],
}


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def main():
    p = os.path.join(ROOT, "lib", "core", "constants", "cities.dart")
    src = open(p, encoding="utf-8").read()
    if "'zunyi': [" in src:
        print("cities.dart already contains zunyi — skipped")
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
    marker = "  'sanming': ["
    assert marker in src, "sanming marker not found"
    src = src.replace(marker, dart + marker, 1)
    open(p, "w", encoding="utf-8").write(src)
    n = sum(len(v) for v in C.values())
    print(f"cities.dart updated with {len(C)} L6 cities ({n} landmarks)")


if __name__ == "__main__":
    main()
