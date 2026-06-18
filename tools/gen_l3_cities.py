# Injects the HSK-3 (Level 3) unit-city Landmark data into
# lib/core/constants/cities.dart. Icons are NOT downloaded here — the single
# source of truth for icon art is tools/fetch_all_icons.py (globally-unique
# icons8 set). After running this: extend fetch_all_icons.py with the L3 icon
# names, then regenerate the TR/EN pack (gen_landmark_packs.py) and the 10
# translated packs (gen_<lang>_landmarks.py).
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# slug: [(icon, nameTr, nameEn, descTr, descEn) x4]
C = {
 'guangzhou': [
  ('tower', 'Kanton Kulesi', 'Canton Tower', "Dünyanın en yüksek kulelerinden 'İnce Bel', geceleri renk renk parlayarak şehre taç olur.", "The slender 'Small Waist', among the world's tallest towers, crowns the city in shifting night colours."),
  ('dimsum', 'Sabah Çayı', 'Morning Tea', "Bambu sepetlerde buğulanan dim sum ve demli çayla yapılan 'yum cha', Kanton sofrasının ruhudur.", "'Yum cha' — dim sum steamed in bamboo baskets with brewed tea — is the soul of Cantonese dining."),
  ('academy', 'Chen Klan Tapınağı', 'Chen Clan Academy', "Oymalı ahşabı ve seramik kabartmalarıyla ünlü klan tapınağı, Kanton zanaatının başyapıtıdır.", "Famed for carved wood and ceramic friezes, the clan hall is a masterpiece of Cantonese craft."),
  ('flower', 'Çiçek Şehri', 'Flower City', "Yıl boyu açan çiçekleriyle Guangzhou'da her yeni yıl dev çiçek pazarları kurulur.", "Blooming year-round, Guangzhou holds vast flower fairs each new year — the 'Flower City'.")],
 'wuhan': [
  ('crane', 'Sarı Turna Kulesi', 'Yellow Crane Tower', "Yangtze'ye bakan bin yıllık kule, Çin şiirinin en ünlü dizelerine ilham verdi.", "Overlooking the Yangtze, the millennium-old tower inspired some of China's most famous poems."),
  ('noodle', 'Reganmian', 'Hot-Dry Noodles', "Susam ezmeli 'sıcak-kuru erişte', Wuhan'ın vazgeçilmez kahvaltısıdır.", "Sesame-paste 'hot-dry noodles' are Wuhan's indispensable breakfast."),
  ('duckneck', 'Acı Ördek Boynu', 'Spicy Duck Neck', "Baharatlı ördek boynu, şehrin gece sohbetlerinin en sevilen atıştırmalığıdır.", "Spicy braised duck neck is the city's favourite snack for late-night chats."),
  ('university', 'Üniversite Kiraz Çiçeği', 'Campus Cherry Blossoms', "Wuhan Üniversitesi'nin kiraz çiçekleri her ilkbahar binlerce ziyaretçiyi çeker.", "Wuhan University's cherry blossoms draw thousands of visitors each spring.")],
 'tianjin': [
  ('eye', 'Tianjin Gözü', 'Tianjin Eye', "Bir köprünün üzerine kurulu dönme dolap, nehrin iki yakasını birden seyrettirir.", "A Ferris wheel built atop a bridge, it overlooks both banks of the river at once."),
  ('baozi', 'Goubuli Mantısı', 'Goubuli Buns', "İnce kıvrımlı buğulama et mantısı, şehrin 150 yıllık imza lezzetidir.", "Pleated steamed pork buns are the city's 150-year-old signature."),
  ('crosstalk', 'Xiangsheng', 'Crosstalk Comedy', "İki kişilik söz oyunlu komedi 'xiangsheng', çay evlerinde doğan bir Tianjin geleneğidir.", "The two-person verbal comedy 'xiangsheng' is a Tianjin tradition born in its teahouses."),
  ('architecture', 'Avrupa Mahallesi', 'European Quarter', "Beş Büyük Cadde'nin Avrupa tarzı villaları, şehre 'mimari müzesi' lakabını kazandırdı.", "The European-style villas of the Five Great Avenues earned the city the name 'museum of architecture'.")],
 'xiamen': [
  ('island', 'Gulangyu Adası', 'Gulangyu Island', "Arabasız sokakları ve sömürge villalarıyla UNESCO mirası ada, bir açık hava müzesidir.", "Car-free lanes and colonial villas make the UNESCO-listed isle an open-air museum."),
  ('piano', 'Piyano Adası', 'Piano Island', "Kişi başına en çok piyanonun düştüğü Gulangyu, 'piyano adası' diye anılır.", "With more pianos per person than anywhere, Gulangyu is called 'piano island'."),
  ('egret', 'Ak Balıkçıl', 'White Egret', "Şehrin simgesi ak balıkçıl, adının 'balıkçıl adası' kökenine işaret eder.", "The white egret, the city's emblem, recalls its old name 'egret island'."),
  ('oyster', 'İstiridyeli Omlet', 'Oyster Omelette', "Taze istiridye ve yumurtayla yapılan çıtır omlet, sahil mutfağının yıldızıdır.", "A crisp omelette of fresh oysters and egg is the star of the coastal kitchen.")],
 'harbin': [
  ('ice', 'Buz Festivali', 'Ice Festival', "Devasa buz saraylarının ışıkla parladığı kış festivali, dünyanın en büyüğüdür.", "Its winter festival of giant illuminated ice palaces is the largest in the world."),
  ('cathedral', 'Aziz Sofya Katedrali', 'Saint Sophia Cathedral', "Soğan kubbeli Rus Ortodoks katedrali, şehrin Avrupa geçmişinin simgesidir.", "The onion-domed Russian Orthodox cathedral is the emblem of the city's European past."),
  ('sausage', 'Harbin Sosisi', 'Red Sausage', "Rus usulü tütsülenmiş kırmızı sosis, şehrin asırlık lezzetidir.", "Russian-style smoked red sausage is the city's century-old delicacy."),
  ('accordion', 'Müzik Şehri', 'Music City', "Rus mirasıyla beslenen Harbin, Çin'in ilk senfoni orkestrasına ev sahipliği yaptı.", "Steeped in Russian heritage, Harbin hosted China's first symphony orchestra.")],
 'fuzhou': [
  ('alley', 'Üç Sokak Yedi Çıkmaz', 'Three Lanes & Seven Alleys', "Beyaz duvarlı, kara kiremitli antik mahalle, Ming-Qing mimarisinin canlı müzesidir.", "The white-walled, black-tiled old quarter is a living museum of Ming-Qing architecture."),
  ('banyan', 'Banyan Şehri', 'Banyan City', "Asırlık dev banyan ağaçları sokakları gölgeler; Fuzhou 'banyan şehri' diye anılır.", "Ancient giant banyan trees shade the streets — Fuzhou is the 'banyan city'."),
  ('hotspring', 'Kaplıcalar', 'Hot Springs', "Şehir merkezinden fışkıran sıcak su kaynakları bin yıldır hamamları besler.", "Hot springs welling up downtown have fed public baths for a thousand years."),
  ('soup', 'Foitiaoqiang', 'Buddha Jumps Over the Wall', "Onlarca malzemeyle demlenen lüks çorba, Fujian mutfağının başyapıtıdır.", "Simmered from dozens of ingredients, this luxe soup is the masterpiece of Fujian cuisine.")],
 'dongguan': [
  ('robot', 'Dünyanın Fabrikası', "World's Factory", "Otomasyonlu fabrikalarıyla Dongguan, dünya elektroniğinin büyük bölümünü üretir.", "With automated factories, Dongguan makes a huge share of the world's electronics."),
  ('basketball', 'Basketbol Şehri', 'Basketball City', "Çin'in en çok şampiyon olan basketbol kulübü bu 'basketbol şehri'nde oynar.", "China's most decorated basketball club plays in this 'basketball city'."),
  ('keyuan', 'Keyuan Bahçesi', 'Keyuan Garden', "Guangdong'un dört ünlü klasik bahçesinden biri, ince havuz ve köşkleriyle bilinir.", "One of Guangdong's four famous classical gardens, prized for its ponds and pavilions."),
  ('cannon', 'Humen Topları', 'Humen Forts', "Afyon Savaşı'nın başladığı Humen kaleleri, afyonun yakıldığı tarihî kıyıdır.", "The Humen forts, where the Opium War began, mark the shore where opium was burned.")],
 'lanzhou': [
  ('beefnoodle', 'Lanzhou Eriştesi', 'Lanzhou Beef Noodles', "Berrak et suyu ve elle çekilen eriştesiyle Lanzhou, Çin'in erişte başkentidir.", "With clear beef broth and hand-pulled noodles, Lanzhou is China's noodle capital."),
  ('waterwheel', 'Su Çarkları', 'Waterwheels', "Sarı Nehir kıyısındaki dev su çarkları, asırlık sulama mühendisliğinin simgesidir.", "Giant waterwheels by the Yellow River symbolise centuries of irrigation engineering."),
  ('statue', 'Sarı Nehir Anası', 'Mother Yellow River', "Nehir kıyısındaki anne-çocuk heykeli, Çin uygarlığını besleyen nehri simgeler.", "The mother-and-child statue on the bank embodies the river that nourished Chinese civilisation."),
  ('raft', 'Koyun Derisi Sal', 'Sheepskin Raft', "Şişirilmiş koyun derilerinden yapılan geleneksel sallar Sarı Nehir'de hâlâ yüzer.", "Traditional rafts of inflated sheepskins still float on the Yellow River.")],
 'urumqi': [
  ('bazaar', 'Büyük Pazar', 'Grand Bazaar', "Minareli kuleleri ve baharat tezgâhlarıyla pazar, İpek Yolu'nun renklerini taşır.", "With minaret towers and spice stalls, the bazaar carries the colours of the Silk Road."),
  ('tianshan', 'Tanrı Dağı Gölü', 'Heavenly Lake', "Tianshan'ın karlı zirveleri altındaki Cennet Gölü, ladin ormanlarıyla çevrilidir.", "Heavenly Lake, below Tianshan's snowy peaks, is ringed by spruce forests."),
  ('kebab', 'Kuzu Kebabı', 'Lamb Kebab', "Kömürde kızaran baharatlı kuzu şişler, Uygur sofrasının vazgeçilmezidir.", "Spiced lamb skewers grilled over coals are essential to the Uyghur table."),
  ('dance', 'Uygur Dansı', 'Uyghur Dance', "Davul ve rebap eşliğindeki dönüşlü Uygur dansları her şenliği renklendirir.", "Whirling Uyghur dances to drum and rawap brighten every celebration.")],
 'haikou': [
  ('coconut', 'Hindistan Cevizi Şehri', 'Coconut City', "Hindistan cevizi palmiyeleriyle kaplı sokaklar Haikou'ya 'hindistan cevizi şehri' adını verir.", "Streets lined with coconut palms give Haikou its name, the 'coconut city'."),
  ('arcade', 'Qilou Eski Sokağı', 'Qilou Arcades', "Güneyin sömürge revaklı 'qilou' binaları, gölgeli kemerli çarşılar oluşturur.", "The south's colonnaded 'qilou' buildings form shaded arcade streets."),
  ('crater', 'Volkan Krateri', 'Volcanic Craters', "Sönmüş yanardağ kraterleri, şehir kıyısında yeşil bir jeopark oluşturur.", "Extinct volcanic craters form a green geopark on the city's edge."),
  ('turtle', 'Tropik Deniz', 'Tropical Sea', "Sıcak berrak suları ve mercanlarıyla kıyı, deniz kaplumbağalarının yuvasıdır.", "Warm clear waters and coral make the coast a home for sea turtles.")],
 'luoyang': [
  ('grotto', 'Longmen Mağaraları', 'Longmen Grottoes', "Kayalara oyulmuş on binlerce Buda heykeli, UNESCO mirası bir sanat hazinesidir.", "Tens of thousands of Buddhas carved into the cliffs form a UNESCO art treasure."),
  ('peony', 'Şakayık Başkenti', 'Peony Capital', "Her nisan açan binlerce şakayık, Luoyang'ı 'şakayık başkenti' yapar.", "Thousands of peonies blooming each April make Luoyang the 'peony capital'."),
  ('whitehorse', 'Beyaz At Tapınağı', 'White Horse Temple', "MS 68'de kurulan tapınak, Çin'in ilk Budist tapınağı kabul edilir.", "Founded in AD 68, the temple is regarded as China's first Buddhist monastery."),
  ('capital', 'Antik Başkent', 'Ancient Capital', "On üç hanedana başkentlik yapan Luoyang, Çin uygarlığının beşiklerindendir.", "Capital to thirteen dynasties, Luoyang is a cradle of Chinese civilisation.")],
 'shantou': [
  ('gongfutea', 'Gongfu Çayı', 'Gongfu Tea', "Küçük fincanlarda törenle demlenen Chaoshan gongfu çayı bir misafirperverlik sanatıdır.", "Ceremoniously brewed in tiny cups, Chaoshan gongfu tea is an art of hospitality."),
  ('beefpot', 'Dana Hotpotu', 'Beef Hotpot', "İnce dilimlenmiş taze dananın saniyelerde haşlandığı Chaoshan hotpotu meşhurdur.", "Chaoshan hotpot, where thin slices of fresh beef cook in seconds, is renowned."),
  ('opera', 'Chaoshan Operası', 'Teochew Opera', "600 yıllık Chaoshan operası, narin şarkıları ve işlemeli kostümleriyle bilinir.", "The 600-year-old Teochew opera is known for delicate songs and embroidered costumes."),
  ('harbor', 'Liman Şehri', 'Port City', "Yurtdışı Çinlilerin memleketi olan liman, deniz ticaretinin eski kapısıdır.", "Hometown of many overseas Chinese, the port is an old gateway of maritime trade.")],
 'baoding': [
  ('mansion', 'Zhili Valilik Konağı', "Governor's Mansion", "Qing döneminin en yüksek taşra makamı, iyi korunmuş bir yönetim sarayıdır.", "The Qing era's highest provincial office is a well-preserved hall of governance."),
  ('donkeyburger', 'Eşek Etli Sandviç', 'Donkey Burger', "Çıtır ekmeğin arasına doldurulan baharatlı eşek eti, bölgenin imza sokak lezzetidir.", "Spiced donkey meat stuffed in crisp flatbread is the region's signature street food."),
  ('balls', 'Baoding Topları', 'Health Balls', "Avuçta döndürülen metal sağlık topları, asırlık bir el egzersizi geleneğidir.", "Metal health balls rotated in the palm are a centuries-old hand-exercise tradition."),
  ('reeds', 'Baiyangdian Sazlığı', 'Baiyangdian Marsh', "Kuzeyin en büyük sulak alanı, sazlıkları ve nilüferleriyle bir kuş cennetidir.", "The north's largest wetland is a bird paradise of reeds and lotus.")],
 'jilin': [
  ('rime', 'Kırağı Ağaçları', 'Rime Ice', "Songhua kıyısındaki ağaçları kaplayan beyaz kırağı, Çin'in dört doğa harikasından biridir.", "White rime coating the trees by the Songhua is one of China's four natural wonders."),
  ('snowboard', 'Kayak Merkezi', 'Ski Resort', "Kalın karı ve uzun sezonuyla şehir, kuzeyin en gözde kayak merkezlerindendir.", "With deep snow and a long season, the city is one of the north's top ski resorts."),
  ('meteorite', 'Göktaşı Müzesi', 'Meteorite Museum', "1976'da düşen dünyanın en büyük taş göktaşı burada sergilenir.", "The world's largest stony meteorite, fallen in 1976, is displayed here."),
  ('skate', 'Songhua Buzu', 'Frozen Songhua', "Donan Songhua Nehri kışın patenci ve yürüyüşçülerle dolan bir buz pistine dönüşür.", "The frozen Songhua River becomes an ice rink filled with skaters and strollers in winter.")],
 'ordos': [
  ('khan', 'Cengiz Han Türbesi', 'Genghis Khan Mausoleum', "Bozkır kahramanı Cengiz Han'ı anan görkemli türbe, Moğol kültürünün kalbidir.", "The grand mausoleum honouring the steppe hero Genghis Khan is the heart of Mongol culture."),
  ('cashmere', 'Kaşmir', 'Cashmere', "Erdos keçilerinin yünüyle dokunan kaşmir, şehri dünya tekstiline taşır.", "Cashmere woven from Erdos goat wool carries the city into world textiles."),
  ('sanddune', 'Şarkı Söyleyen Kumlar', 'Singing Sands', "Kayınca uğultu çıkaran dev kumullar, Kubuqi Çölü'nün gözde durağıdır.", "Giant dunes that hum when you slide down them are the Kubuqi Desert's favourite stop."),
  ('yurt', 'Moğol Çadırı', 'Mongolian Yurt', "Uçsuz bozkırlara kurulan beyaz keçe yurtlar, göçebe yaşamın simgesidir.", "White felt yurts pitched on endless grassland symbolise nomadic life.")],
 'jining': [
  ('confucius', 'Konfüçyüs Tapınağı', 'Confucius Temple', "Yakındaki Qufu'da bilge Konfüçyüs'ün tapınağı, evi ve mezarı UNESCO mirasıdır.", "In nearby Qufu, the temple, mansion and tomb of the sage Confucius are UNESCO-listed."),
  ('barge', 'Büyük Kanal', 'Grand Canal', "Pekin-Hangzhou Kanalı'nın işlek limanı Jining, kanal kültürünün merkeziydi.", "A busy port on the Beijing-Hangzhou Canal, Jining was a hub of canal culture."),
  ('sword', 'Liangshan Kahramanları', 'Liangshan Heroes', "Klasik 'Su Kenarı' romanının 108 haydut kahramanı bu bataklık dağlarda toplandı.", "The 108 outlaw heroes of the classic 'Water Margin' gathered in these marsh hills."),
  ('fishnet', 'Weishan Gölü', 'Weishan Lake', "Kuzeyin en büyük nilüfer gölünde balıkçılar ağlarını asırlık usulle atar.", "On the north's largest lotus lake, fishermen cast their nets in age-old ways.")],
 'langfang': [
  ('culture', 'İpek Yolu Kültür Merkezi', 'Silk Road Culture Center', "Şehrin dev modern kültür merkezi, İpek Yolu sanatlarını bir çatı altında toplar.", "The city's giant modern culture centre gathers Silk Road arts under one roof."),
  ('furniture', 'Mobilya Şehri', 'Furniture City', "Komşu Xianghe, Çin'in en büyük mobilya üretim ve ticaret merkezlerindendir.", "Neighbouring Xianghe is one of China's largest furniture making and trading hubs."),
  ('tunnel', 'Song-Liao Savaş Tünelleri', 'Ancient War Tunnels', "Yer altına kazılmış bin yıllık askerî tüneller, eski sınır savunmasının izini taşır.", "Thousand-year-old military tunnels dug underground trace an old frontier defence."),
  ('themepark', "Tianxia Diyi Cheng", "'No.1 City' Park", "Antik surlu bir kenti yeniden canlandıran dev tema parkı ailelere kapısını açar.", "A vast theme park recreating an ancient walled city welcomes families.")],
 'yancheng': [
  ('salt', 'Tuz Şehri', 'City of Salt', "Adı 'tuz kalesi' demek olan Yancheng, asırlarca Çin'in tuz üretiminin merkeziydi.", "Its name means 'salt fort'; for centuries Yancheng was a centre of China's salt production."),
  ('crane', 'Telli Turna', 'Red-Crowned Crane', "Kıyı sulak alanı, dünyanın en büyük yabani telli turna kışlağıdır.", "The coastal wetland is the world's largest wintering ground for wild red-crowned cranes."),
  ('elk', 'Milu Geyiği', "Père David's Deer", "Bir zamanlar nesli tükenen milu geyiği, bu sulak alanlarda yeniden çoğaldı.", "Once extinct in the wild, the milu deer has bred back to life in these wetlands."),
  ('wetland', 'Kıyı Sulak Alanı', 'Coastal Wetland', "UNESCO mirası gelgit düzlükleri, göçmen kuşların küresel bir durağıdır.", "The UNESCO-listed tidal flats are a global stop for migratory birds.")],
 'huzhou': [
  ('brush', 'Hu Fırçası', 'Hu Writing Brush', "Çin kaligrafisinin 'dört hazinesinden' biri olan Hu fırçası burada yapılır.", "The Hu brush, one of the 'four treasures' of Chinese calligraphy, is made here."),
  ('bamboo', 'Anji Bambu Denizi', 'Anji Bamboo Sea', "Uçsuz yeşil bambu ormanları sinemaya ilham verdi ve havayı serin tutar.", "Endless green bamboo forests, which inspired films, keep the air cool."),
  ('silkworm', 'İpek Böceği', 'Silk Worm', "Tai Gölü'nün güney kıyısı, bin yıldır dut ipekçiliğinin merkezidir.", "The southern shore of Lake Tai has been a centre of mulberry silk for a thousand years."),
  ('whitetea', 'Anji Beyaz Çayı', 'Anji White Tea', "Soluk yeşil yaprakları ve tatlı tadıyla Anji beyaz çayı Çin'in nadidelerindendir.", "With pale leaves and a sweet taste, Anji white tea is among China's rarest.")],
 'quzhou': [
  ('go', 'Go Oyunu', 'Go (Weiqi)', "Lanke Dağı efsanesiyle Go oyununun kutsandığı şehir 'Go diyarı' sayılır.", "Hallowed by the Mount Lanke legend, the city is revered as a 'land of Go'."),
  ('peaks', 'Jianglang Dağı', 'Mount Jianglang', "Gökyüzüne uzanan üç dev taş sütun, UNESCO mirası eşsiz bir manzaradır.", "Three giant stone pillars rising to the sky form a unique UNESCO landscape."),
  ('ponkan', 'Quzhou Mandalinası', 'Quzhou Ponkan', "Tatlı kabuklu ponkan mandalinası, ılıman tepelerin kış armağanıdır.", "The sweet-skinned ponkan tangerine is the winter gift of the mild hills."),
  ('cake', 'Közde Pide', 'Baked Flatbread', "Fırın duvarında pişirilen çıtır susam pidesi, yerel kahvaltının klasiğidir.", "Crisp sesame flatbread baked on the oven wall is a local breakfast classic.")],
 'huainan': [
  ('tofu', "Tofu'nun Doğduğu Yer", 'Birthplace of Tofu', "Bagong Dağı'nda 2.000 yıl önce icat edilen tofu, dünya mutfağına buradan yayıldı.", "Invented on Mount Bagong 2,000 years ago, tofu spread to world cuisine from here."),
  ('coalmine', 'Kömür Şehri', 'Coal City', "Zengin kömür yataklarıyla Huainan, Doğu Çin'in enerji üssüdür.", "Rich in coal seams, Huainan is an energy base of eastern China."),
  ('oldtown', 'Shou Antik Kenti', 'Shou County Old Town', "Tam korunmuş Song dönemi şehir suru, antik savunma mimarisinin nadide örneğidir.", "The fully preserved Song-era city wall is a rare example of ancient defensive design."),
  ('classic', 'Huainanzi', 'The Huainanzi', "Prens Liu An'ın derlediği klasik felsefe metni bu topraklarda yazıldı.", "The classic of philosophy compiled by Prince Liu An was written on these lands.")],
 'jingdezhen': [
  ('porcelain', 'Porselen Başkenti', 'Porcelain Capital', "Bin yıldır imparatorluk porselenini üreten şehir, dünyanın 'porselen başkenti'dir.", "Producing imperial porcelain for a thousand years, the city is the world's 'porcelain capital'."),
  ('kiln', 'Antik Fırın', 'Ancient Kiln', "Odunla yakılan ejderha biçimli fırınlar, geleneksel porselen pişirme sanatını yaşatır.", "Wood-fired dragon-shaped kilns keep the traditional art of firing porcelain alive."),
  ('bluewhite', 'Mavi-Beyaz Porselen', 'Blue & White', "Kobalt mavisi desenli beyaz porselen, şehrin dünyaca tanınan imzasıdır.", "White porcelain with cobalt-blue designs is the city's world-famous signature."),
  ('painting', 'Porselen Resmi', 'Porcelain Painting', "Usta ressamların ince fırçayla işlediği porselen, bir tablo kadar değerlidir.", "Porcelain painted with fine brushes by master artists is prized like fine paintings.")],
 'jian': [
  ('jinggang', 'Jinggang Dağları', 'Jinggang Mountains', "Çin devriminin ilk üssü olan sisli dağlar, 'kızıl turizmin' kalbidir.", "The misty mountains, the revolution's first base, are the heart of 'red tourism'."),
  ('torch', 'Devrim Kıvılcımı', 'Revolutionary Spark', "'Tek kıvılcım bozkırı tutuşturur' sözünün doğduğu topraklar, tarihî bir anıt-alandır.", "The land that gave rise to 'a single spark can start a prairie fire' is a historic memorial."),
  ('academy', 'Bailuzhou Akademisi', 'Bailuzhou Academy', "Gan Nehri adasındaki bin yıllık akademi, sayısız imparatorluk âlimi yetiştirdi.", "The millennium-old academy on a Gan River isle schooled countless imperial scholars."),
  ('pine', 'Jinggang Çamları', 'Jinggang Pines', "Sislerin arasından yükselen kızıl çamlar, dağ ruhunun ve dayanıklılığın simgesidir.", "Red pines rising through the mist symbolise the mountain spirit and resilience.")],
 'nanping': [
  ('wuyi', 'Wuyi Dağları', 'Wuyi Mountains', "Kızıl kayalıkları ve yeşil vadileriyle UNESCO mirası dağlar, doğa ve kültür hazinesidir.", "With red cliffs and green gorges, the UNESCO-listed mountains are a treasure of nature and culture."),
  ('rocktea', 'Da Hong Pao', 'Rock Tea', "Kayalıklarda yetişen 'Büyük Kızıl Cübbe' oolong çayı, dünyanın en pahalı çaylarındandır.", "The cliff-grown 'Big Red Robe' oolong is among the world's most expensive teas."),
  ('bambooraft', 'Dokuz Kıvrım Salı', 'Nine-Bend Raft', "Bambu sallarla süzülen Dokuz Kıvrım Deresi, kızıl kayalar arasında akar.", "Drifting bamboo rafts glide down the Nine-Bend Stream between red cliffs."),
  ('scholar', 'Zhu Xi', 'Master Zhu Xi', "Neo-Konfüçyüsçülüğün kurucusu Zhu Xi, dersini bu dağ eteklerinde verdi.", "Zhu Xi, founder of Neo-Confucianism, taught at the foot of these mountains.")],
}


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def main():
    p = os.path.join(ROOT, "lib", "core", "constants", "cities.dart")
    src = open(p, encoding="utf-8").read()
    if "'guangzhou': [" in src:
        print("cities.dart already contains guangzhou — skipped")
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
    print(f"cities.dart updated with {len(C)} L3 cities ({n} landmarks)")


if __name__ == "__main__":
    main()
