# One-shot generator for the HSK-2 (Level 2) unit cities: downloads a sharp
# 256px Twemoji landmark icon for every L2 unit city (4 each), drops a photo
# placeholder sharing the art, and injects the Landmark data into
# lib/core/constants/cities.dart. Mirror of tools/gen_l1_cities.py, but renders
# at 256px (via images.weserv.nl) like tools/regen_city_icons.py so the icons
# match the re-rendered L1 set. Baotou already has landmarks (skipped).
#
# After running this: regenerate the TR/EN packs (gen_landmark_packs.py) and the
# 10 translated packs (gen_<lang>_landmarks.py).
import os
import sys
import time
import shutil
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IC_DIR = os.path.join(ROOT, "assets", "cities")
PH_DIR = os.path.join(ROOT, "assets", "landmarks")

# (icon-slug, emoji, nameTr, nameEn, descTr, descEn) x4 per city. Emojis are
# distinct WITHIN each city (so the four node icons never look identical).
C = {
 'shanghai': [
  ('pearl', '🌃', 'Oryantal İnci Kulesi', 'Oriental Pearl Tower', "Huangpu kıyısında yükselen pembe küreli kule, modern Şanghay'ın simgesidir.", "Rising over the Huangpu with its pink spheres, the tower is the icon of modern Shanghai."),
  ('bund', '🏦', 'Bund', 'The Bund', "Nehir kıyısındaki tarihî banka ve otel cepheleri, eski Şanghay'ın görkemini yansıtır.", "The riverfront's historic bank and hotel façades reflect old Shanghai's grandeur."),
  ('garden', '🪴', 'Yuyuan Bahçesi', 'Yu Garden', "Ming döneminden kalma klasik bahçe, kayalıkları ve havuzlarıyla şehrin kalbinde bir vahadır.", "A Ming-era classical garden, its rockeries and ponds form an oasis in the city's heart."),
  ('xlb', '🥟', 'Xiaolongbao', 'Soup Dumplings', "İçi sıcak çorbayla dolu buğulama hamur lokması, Şanghay kahvaltısının başyapıtıdır.", "Steamed parcels filled with hot broth are the masterpiece of Shanghai breakfast.")],
 'hangzhou': [
  ('lake', '🏞', 'Batı Gölü', 'West Lake', "Söğütleri, adacıkları ve kemerli köprüleriyle Çin şiirinin en çok övdüğü göldür.", "With willows, islets and arched bridges, it is the lake most praised in Chinese poetry."),
  ('tea', '🍵', 'Longjing Çayı', 'Longjing Tea', "Göl çevresi yamaçlarda yetişen 'Ejderha Kuyusu' yeşil çayı Çin'in en ünlüsüdür.", "Grown on the slopes around the lake, 'Dragon Well' green tea is China's most famous."),
  ('temple', '🛕', 'Lingyin Tapınağı', 'Lingyin Temple', "1700 yıllık 'Ruhların İnzivası' tapınağı, kaya oymaları ve dev Buda heykeliyle ünlüdür.", "The 1,700-year-old 'Temple of the Soul's Retreat' is famed for rock carvings and a giant Buddha."),
  ('silk', '🧵', 'İpek Şehri', 'Silk City', "Hangzhou ipeği bin yıldır dokunur; şehir İpek Yolu'nun doğu ucunun zenginliğidir.", "Hangzhou silk has been woven for a thousand years — the wealth of the Silk Road's eastern end.")],
 'chongqing': [
  ('hongya', '🏙', 'Hongya Mağarası', 'Hongya Cave', "Uçuruma asılı ışıl ışıl ahşap teras yapısı, gece nehir kıyısında masal gibi parlar.", "A glowing stilt-house complex clinging to the cliff, it shines like a fairytale over the river at night."),
  ('hotpot', '🌶', 'Chongqing Hotpotu', 'Chongqing Hotpot', "Kıpkırmızı acı yağ ve uyuşturan biberle kaynayan hotpot, dağ şehrinin ateşli ruhudur.", "Bubbling with fiery oil and numbing pepper, hotpot is the fiery soul of the mountain city."),
  ('monorail', '🚝', 'Dağ Şehri Metrosu', 'Mountain Monorail', "Binaların içinden geçen hafif metro, tepelere kurulu şehrin simge manzarasıdır.", "The light-rail threading through a building is the signature sight of this city built on hills."),
  ('river', '🚢', 'Yangtze Geçidi', 'Yangtze Gorges', "Üç Vadi gemi turları bu limandan başlar; iki nehrin birleştiği yerde şehir yükselir.", "Three Gorges cruises depart from this port, where the city rises at the meeting of two rivers.")],
 'dalian': [
  ('square', '🎡', 'Xinghai Meydanı', 'Xinghai Square', "Asya'nın en büyük şehir meydanı, deniz kıyısında festival ve gösterilerle dolar.", "Asia's largest city square fills with festivals and shows along the seafront."),
  ('beach', '🏖', 'Sahiller', 'Beaches', "Kayalık koyları ve serin yazlarıyla Dalian, kuzeyin gözde tatil kıyısıdır.", "With rocky coves and cool summers, Dalian is the north's favourite seaside resort."),
  ('football', '⚽', 'Futbol Şehri', 'Football City', "Çin'in 'futbol beşiği'; ülkenin en çok şampiyonluk kazanan kulüpleri burada doğdu.", "China's 'cradle of football' — the nation's most decorated clubs were born here."),
  ('seafood', '🦐', 'Deniz Ürünleri', 'Seafood', "Soğuk Sarı Deniz'in deniz tarağı, karides ve deniz kestanesi şehrin sofrasını süsler.", "Cold Yellow Sea scallops, prawns and sea urchin grace the city's tables.")],
 'shenyang': [
  ('palace', '🏯', 'Mukden Sarayı', 'Mukden Palace', "Qing hanedanının ilk sarayı; Pekin'deki Yasak Şehir'in küçük kardeşidir.", "The Qing dynasty's first palace — a smaller sibling of Beijing's Forbidden City."),
  ('tomb', '🏛', 'Qing Türbeleri', 'Qing Tombs', "Şehri çevreleyen Doğu ve Kuzey türbeleri, hanedan kurucularının anıt mezarlarıdır.", "The East and North tombs ringing the city are the monumental mausoleums of the dynasty's founders."),
  ('factory', '🏭', 'Sanayi Beşiği', 'Industrial Cradle', "Çin'in ağır sanayisi burada doğdu; dev fabrikalar 'Doğu'nun Ruhr'u' lakabını kazandırdı.", "China's heavy industry was born here; vast factories earned it the name 'Ruhr of the East'."),
  ('dumpling', '🥟', 'Laobian Mantısı', 'Laobian Dumplings', "200 yıllık Laobian buğulama mantısı, kuzey sofrasının imza lezzetidir.", "Two-hundred-year-old Laobian steamed dumplings are the signature dish of the northern table.")],
 'hefei': [
  ('judge', '⚖', 'Bao Gong Türbesi', "Lord Bao's Shrine", "Adaletin simgesi yargıç Bao Zheng burada doğdu; anıtı dürüstlüğün tapınağıdır.", "Born here, the upright judge Bao Zheng is justice incarnate; his shrine is a temple to integrity."),
  ('science', '🔬', 'Bilim Şehri', 'Science City', "Çin'in önde gelen üniversite ve laboratuvarlarına ev sahipliği yapan teknoloji merkezidir.", "A tech hub hosting some of China's leading universities and laboratories."),
  ('lake', '🏞', 'Chaohu Gölü', 'Lake Chaohu', "Çin'in beş büyük tatlı su gölünden biri; beyaz balığı ve yengeciyle ünlüdür.", "One of China's five great freshwater lakes, famed for its whitefish and crab."),
  ('cake', '🍘', 'Lu Susam Çöreği', 'Lu Sesame Cake', "Tatlı dolgulu susam çöreği, eski Luzhou şehrinin asırlık ikramıdır.", "A sweet-filled sesame cake is the age-old treat of old Luzhou.")],
 'foshan': [
  ('wingchun', '🥋', 'Wing Chun', 'Wing Chun', "Yip Man ve Bruce Lee'nin kökleri buraya uzanır; Wing Chun dövüş sanatının yuvasıdır.", "Home of Wing Chun martial art — the roots of Ip Man and Bruce Lee reach here."),
  ('lion', '🦁', 'Aslan Dansı', 'Lion Dance', "Güney aslan dansının başkenti; festivallerde rengârenk aslanlar sütunlarda zıplar.", "The capital of southern lion dance; festival lions leap across poles in dazzling colour."),
  ('ceramic', '🏺', 'Shiwan Seramiği', 'Shiwan Pottery', "Bin yıllık çömlek ocakları, canlı figürlü Shiwan seramiğini hâlâ pişirir.", "Thousand-year kilns still fire the lively figurines of Shiwan pottery."),
  ('opera', '🎭', 'Kanton Operası', 'Cantonese Opera', "Güney Çin'in en sevilen sahne sanatı bu topraklarda olgunlaştı.", "Southern China's best-loved stage art matured on these lands.")],
 'guiyang': [
  ('pavilion', '🏯', 'Jiaxiu Köşkü', 'Jiaxiu Pavilion', "Nanming Nehri üzerindeki üç katlı köşk, 400 yıldır şehrin simgesidir.", "The three-tiered pavilion on the Nanming River has been the city's emblem for 400 years."),
  ('sourfish', '🐟', 'Ekşi Çorbalı Balık', 'Sour Soup Fish', "Domates ve ekşi mayalı kırmızı çorbada pişen balık, Guizhou'nun imza yemeğidir.", "Fish simmered in a tangy fermented-tomato red broth is Guizhou's signature dish."),
  ('waterfall', '💦', 'Huangguoshu Şelalesi', 'Huangguoshu Falls', "Asya'nın en büyük şelalelerinden biri, gürül gürül dökülerek gökkuşakları yaratır.", "One of Asia's largest waterfalls thunders down, throwing up rainbows."),
  ('miao', '💃', 'Miao Kültürü', 'Miao Culture', "Gümüş başlıklı Miao halkının şenlikleri ve nakışları dağ köylerini renklendirir.", "The silver-crowned Miao people's festivals and embroidery brighten the mountain villages.")],
 'changchun': [
  ('film', '🎬', 'Film Şehri', 'Film City', "Çin sinemasının doğduğu stüdyolar burada; 'Doğu'nun Hollywood'u' diye anılır.", "The studios where Chinese cinema was born stand here — the 'Hollywood of the East'."),
  ('car', '🚗', 'Otomobil Şehri', 'Auto City', "Çin'in ilk yerli otomobili bu fabrikalardan çıktı; ülkenin araba başkentidir.", "China's first home-built car rolled out of these factories — the nation's auto capital."),
  ('palace', '🏯', 'Kukla Mançu Sarayı', 'Puppet Palace', "Son imparatorun yaşadığı saray, dalgalı bir tarihin sessiz tanığıdır.", "The palace where the last emperor lived is a silent witness to a turbulent history."),
  ('snow', '❄', 'Kış ve Kar', 'Winter Snow', "Uzun, bembeyaz kışlarıyla şehir, buz heykelleri ve kayak pistleriyle parlar.", "Through long, white winters the city sparkles with ice sculptures and ski runs.")],
 'xining': [
  ('lake', '🏞', 'Qinghai Gölü', 'Lake Qinghai', "Çin'in en büyük tuz gölü, yazın çevresini saran sarı kolza tarlalarıyla ünlüdür.", "China's largest salt lake is famed for the yellow rapeseed fields that ring it in summer."),
  ('monastery', '🛕', 'Kumbum Manastırı', 'Kumbum Monastery', "Tibet Budizminin altı büyük manastırından biri; tereyağı heykelleriyle meşhurdur.", "One of the six great monasteries of Tibetan Buddhism, renowned for its yak-butter sculptures."),
  ('flower', '🌼', 'Kolza Çiçeği', 'Rapeseed Blossom', "Temmuzda plato altın sarısı kolza tarlalarıyla ufka kadar kaplanır.", "In July the plateau is blanketed to the horizon in golden rapeseed fields."),
  ('lamb', '🍢', 'Yak ve Kuzu', 'Yak & Lamb', "Hui ve Tibet mutfağının elle çekilmiş eriştesi ve kuzu şişi yaylanın lezzetidir.", "Hand-pulled noodles and lamb skewers of Hui and Tibetan cooking are the flavours of the plateau.")],
 'guilin': [
  ('karst', '⛰', 'Li Nehri Dağları', 'Li River Karst', "Sis içinde yükselen kireçtaşı tepeler, '20 yuan'lık banknotun manzarasıdır.", "Limestone peaks rising from the mist are the scene printed on the 20-yuan note."),
  ('elephant', '🐘', 'Fil Hortumu Tepesi', 'Elephant Trunk Hill', "Hortumunu nehre daldıran fil biçimli kaya, şehrin sevilen simgesidir.", "The elephant-shaped rock dipping its trunk into the river is the city's beloved emblem."),
  ('terrace', '🌾', 'Longji Pirinç Terasları', 'Longji Rice Terraces', "Dağ yamaçlarını saran 'Ejderha Sırtı' terasları, asırlık emeğin merdivenidir.", "The 'Dragon's Backbone' terraces wrapping the slopes are a staircase of centuries of toil."),
  ('osmanthus', '🌸', 'Tatlı Osmanthus', 'Osmanthus Blossom', "Adı 'osmanthus ormanı' demektir; sonbaharda şehir tatlı çiçek kokusuna boğulur.", "Its name means 'osmanthus forest'; in autumn the city drowns in sweet blossom scent.")],
 'wenzhou': [
  ('merchant', '💼', 'Tüccar Ruhu', 'Merchant Spirit', "'Çin'in Yahudileri' denen Wenzhoulu girişimciler dünyaya yayılmış iş ağı kurar.", "Called 'China's Jews', Wenzhou entrepreneurs build business networks across the globe."),
  ('shoe', '👞', 'Ayakkabı ve Deri', 'Shoes & Leather', "Dünyanın deri ayakkabılarının büyük kısmı bu fabrika şehrinden çıkar.", "A huge share of the world's leather shoes comes from this factory city."),
  ('mountain', '🏔', 'Yandang Dağları', 'Yandang Mountains', "Şelaleleri ve sivri zirveleriyle ünlü dağlar, 'denizin üstündeki ilk dağ' sayılır.", "Famed for waterfalls and jagged peaks, these are hailed as 'the first mountain by the sea'."),
  ('seafood', '🦑', 'Deniz Ürünleri', 'Seafood', "Doğu Çin Denizi'nin kalamar, deniz tarağı ve balığı yerel sofranın temelidir.", "Squid, scallops and fish from the East China Sea are the base of the local table.")],
 'tangshan': [
  ('memorial', '🕯', 'Deprem Anıtı', 'Earthquake Memorial', "1976 büyük depreminin anısına kurulan park, yeniden doğan şehrin simgesidir.", "The memorial park to the great 1976 quake is the emblem of a city reborn."),
  ('coal', '⛏', 'Kömür ve Çelik', 'Coal & Steel', "Çin'in ilk modern kömür madeni ve demiryolu burada açıldı; sanayinin beşiğidir.", "China's first modern coal mine and railway opened here — a cradle of industry."),
  ('ceramic', '🏺', 'Tangshan Seramiği', 'Tangshan Ceramics', "'Kuzeyin porselen şehri'; kemik porseleni masaları zarafetle donatır.", "The 'porcelain city of the north' — its bone china graces tables with elegance."),
  ('lake', '🏞', 'Nanhu Parkı', 'Nanhu Park', "Eski maden çukurundan doğan göl-park, şehrin yeşil ciğeri oldu.", "A lake-park born from an old mining pit became the city's green lung.")],
 'anshan': [
  ('steel', '🏭', 'Çelik Şehri', 'Steel City', "Çin'in en büyük çelik kombinası burada kuruldu; ülkenin 'çelik başkenti'dir.", "China's largest steel works was founded here — the nation's 'steel capital'."),
  ('jade', '💎', 'Xiuyan Yeşimi', 'Xiuyan Jade', "Dünyanın en büyük yeşim heykeli buradadır; şehir Çin'in yeşim diyarıdır.", "The world's largest jade carving is here; the city is China's land of jade."),
  ('mountain', '⛰', 'Qianshan Dağı', 'Mount Qian', "'Bin Lotus Zirvesi' dağı, tapınakları ve kayalarıyla kuzeyin kutsal dorukudur.", "The 'Thousand Lotus Peaks', with its temples and crags, is the north's sacred summit."),
  ('spring', '♨', 'Tanggangzi Kaplıcası', 'Tanggangzi Springs', "Bin yıldır şifa aranan sıcak su kaplıcaları imparatorları bile ağırladı.", "Hot springs sought for healing for a thousand years once hosted emperors too.")],
 'linyi': [
  ('market', '🛒', 'Toptan Çarşı', 'Wholesale Market', "Kuzey Çin'in en büyük toptan ticaret merkezi, mallarını tüm ülkeye dağıtır.", "Northern China's largest wholesale hub ships its goods across the whole country."),
  ('brush', '🖌', 'Wang Xizhi', 'Master Calligrapher', "Çin'in 'kaligrafi bilgesi' Wang Xizhi burada doğdu; şehir mürekkebin diyarıdır.", "China's 'sage of calligraphy' Wang Xizhi was born here; the city is the land of ink."),
  ('mountain', '🏔', 'Mengshan Dağı', 'Mount Meng', "Şandong'un ikinci yüksek dağı, temiz havası ve şelaleleriyle 'oksijen barı'dır.", "Shandong's second-highest mountain is an 'oxygen bar' of clean air and waterfalls."),
  ('pancake', '🫓', 'Jianbing', 'Yimeng Pancake', "İnce mısır gözlemesi 'jianbing', Yimeng dağ halkının asırlık temel ekmeğidir.", "The thin corn pancake 'jianbing' is the age-old staple of the Yimeng mountain folk.")],
 'cangzhou': [
  ('lion', '🦁', 'Demir Aslan', 'Iron Lion', "1100 yıllık dev dökme demir aslan heykeli, şehrin gururlu nişanıdır.", "The 1,100-year-old giant cast-iron lion is the city's proud badge."),
  ('martial', '🥋', 'Dövüş Sanatları', 'Martial Arts', "Çin'in 'wushu memleketi'; ünlü ustalar ve dövüş okulları buradan çıktı.", "China's 'home of wushu' — famed masters and fighting schools came from here."),
  ('canal', '🛶', 'Büyük Kanal', 'Grand Canal', "Pekin-Hangzhou Büyük Kanalı şehrin içinden geçer; eski iskeleler hâlâ durur.", "The Beijing-Hangzhou Grand Canal runs through the city; old wharves still stand."),
  ('jujube', '🍒', 'Altın Hünnap', 'Golden Jujube', "İnce kabuklu tatlı 'altın iplik' hünnabı, kuru meyvenin kralı sayılır.", "The thin-skinned, sweet 'golden-thread' jujube is hailed as the king of dried fruit.")],
 'nantong': [
  ('textile', '🧶', 'Tekstil Şehri', 'Textile City', "Çin'in ev tekstili başkenti; pamuklu kumaşları dünya pazarlarına yayılır.", "China's home-textile capital — its cotton cloth reaches markets worldwide."),
  ('mountain', '⛰', 'Langshan', 'Mount Lang', "Yangtze ağzında yükselen beş tepeli kutsal dağ, hac ve manzara yeridir.", "Rising at the Yangtze's mouth, the five-peaked sacred hill is a place of pilgrimage and views."),
  ('kite', '🪁', 'Banyao Uçurtması', 'Whistling Kite', "Gökte uğuldayan düdüklü 'banyao' uçurtmaları şehrin asırlık zanaatıdır.", "The humming, whistle-fitted 'banyao' kites are the city's age-old craft."),
  ('school', '🎓', 'Eğitim Öncüsü', 'Education Pioneer', "Sanayici Zhang Jian burada Çin'in ilk modern okul ve müzelerini kurdu.", "The industrialist Zhang Jian founded China's first modern schools and museum here.")],
 'taizhou': [
  ('opera', '🎭', 'Mei Lanfang', 'Mei Lanfang', "Pekin operasının efsanevi ustası Mei Lanfang'ın memleketi burasıdır.", "This is the hometown of Mei Lanfang, legendary master of Peking opera."),
  ('tea', '🍵', 'Sabah Çayı', 'Morning Tea', "Buğulama börek ve demli çayla başlayan 'zaocha' kahvaltısı şehrin ritüelidir.", "The 'zaocha' breakfast of steamed buns and brewed tea is the city's ritual."),
  ('boat', '🚣', 'Qintong Kayık Şenliği', 'Qintong Boat Festival', "Baharda yüzlerce kürekçinin yarıştığı sandal şenliği nehri canlandırır.", "In spring a festival of hundreds of rowers racing brings the river to life."),
  ('meatball', '🍡', 'Aslan Başı Köfte', "Lion's Head Meatball", "İri, yumuşacık domuz köftesi 'aslan başı', Huaiyang mutfağının klasiğidir.", "The big, tender pork meatball 'lion's head' is a classic of Huaiyang cuisine.")],
 'jinhua': [
  ('ham', '🍖', 'Jinhua Jambonu', 'Jinhua Ham', "Asırlık tuzlama yöntemiyle olgunlaşan kırmızı jambon, Çin'in en ünlüsüdür.", "Cured by a centuries-old method, the red ham is the most famous in China."),
  ('film', '🎬', 'Hengdian Stüdyoları', 'Hengdian Studios', "Dünyanın en büyük açık hava film platosu; sayısız tarihî dizi burada çekilir.", "The world's largest outdoor film set — countless period dramas are shot here."),
  ('cave', '🕳', 'Shuanglong Mağarası', 'Shuanglong Cave', "Tekneyle alçak bir kaya kapısından girilen yeraltı mağarası nefes kesir.", "An underground cavern entered by boat through a low rock gate takes the breath away."),
  ('bridge', '🌉', 'Eski Köprüler', 'Ancient Bridges', "Wuzhou'nun kemerli taş köprüleri ve su kasabaları Jiangnan'ın inceliğini taşır.", "Arched stone bridges and water towns carry the grace of Jiangnan.")],
 'wuhu': [
  ('park', '🎢', 'Fangte Lunaparkı', 'Fangte Wonderland', "Çin'in en büyük tema parklarından biri; ailelere heyecan dolu günler sunar.", "One of China's largest theme parks offers families days full of thrills."),
  ('ironart', '⚒', 'Wuhu Demir Resmi', 'Iron Painting', "Demiri döverek yapılan zarif 'demir resim' tabloları, 300 yıllık bir zanaattır.", "Elegant 'iron paintings' forged from wrought iron are a 300-year-old craft."),
  ('rice', '🌾', 'Pirinç Limanı', 'Rice Port', "Yangtze kıyısındaki şehir, tarih boyunca Çin'in en büyük pirinç pazarıydı.", "The Yangtze-side city was historically China's largest rice market."),
  ('river', '🚢', 'Yangtze Limanı', 'Yangtze Port', "İşlek nehir limanı, şehri Anhui'nin denize açılan kapısı yapar.", "A busy river port makes the city Anhui's gateway to the sea.")],
 'huangshan': [
  ('peak', '🏔', 'Sarı Dağ', 'Yellow Mountain', "Granit zirveleri, bulut denizi ve eğri çamlarıyla Çin'in en ünlü dağıdır.", "With granite peaks, a sea of clouds and gnarled pines, it is China's most famous mountain."),
  ('village', '🏘', 'Hongcun Köyü', 'Hongcun Village', "Su kanallı, beyaz duvarlı Hui köyleri UNESCO mirasıdır; resimlerden fırlamış gibidir.", "The water-laced, white-walled Hui villages are UNESCO-listed and look straight out of a painting."),
  ('tea', '🍃', 'Huangshan Maofeng', 'Maofeng Tea', "Sisli yamaçlarda toplanan tüylü uçlu yeşil çay, Çin'in on ünlü çayından biridir.", "Picked on misty slopes, the downy-tipped green tea is one of China's ten famous teas."),
  ('ink', '🖌', 'Hui Mürekkep ve Mimari', 'Huizhou Ink & Arts', "Hui mürekkebi, oymalı ahşap evleri ve hat sanatı bölgenin kültür hazinesidir.", "Hui ink, carved timber houses and calligraphy are the region's cultural treasure.")],
 'yichun': [
  ('moon', '🌙', 'Mingyue Dağı', 'Mount Mingyue', "'Parlak Ay' dağı, sıcak su kaynakları ve teleferik manzaralarıyla ünlüdür.", "The 'Bright Moon' mountain is famed for hot springs and cable-car views."),
  ('spring', '♨', 'Selenyum Kaplıcaları', 'Hot Springs', "Nadir selenyumlu sıcak su kaynakları, şehri Çin'in şifa-banyo merkezi yaptı.", "Rare selenium-rich hot springs made the city China's spa-bathing centre."),
  ('zen', '☸', 'Zen Budizmi', 'Chan Buddhism', "Çin Zen mezheplerinin köklerini taşıyan dağ tapınakları sessizliğe çağırır.", "Mountain temples rooted in China's Chan sects call one to stillness."),
  ('rice', '🌾', 'Pirinç Ovası', 'Rice Plain', "Verimli Yuan-He ovası, tarih boyunca Jiangxi'nin tahıl ambarı olmuştur.", "The fertile Yuan-He plain has long been Jiangxi's granary.")],
 'zhangzhou': [
  ('narcissus', '🌼', 'Nergis Çiçeği', 'Narcissus', "Çin'in en ünlü nergis soğanları burada yetişir; bahar şenliklerinin simgesidir.", "China's most famous narcissus bulbs grow here — the emblem of spring festivals."),
  ('tulou', '🏯', 'Hakka Tulou', 'Hakka Earth Houses', "Dev yuvarlak topraktan kale-evler UNESCO mirasıdır; bir köyü tek çatı altında toplar.", "Giant round rammed-earth fortresses are UNESCO-listed, gathering a village under one roof."),
  ('banana', '🍌', 'Tropik Meyveler', 'Tropical Fruit', "Muz, longan ve mandalina bahçeleri sıcak deltayı yıl boyu yeşertir.", "Banana, longan and tangerine groves keep the warm delta green year-round."),
  ('coast', '🏝', 'Dongshan Adası', 'Dongshan Island', "Altın kumlu plajları ve balıkçı köyleriyle ada, güney kıyısının incisidir.", "With golden beaches and fishing villages, the island is the pearl of the southern coast.")],
}


def codepoints(e):
    return '-'.join(f'{ord(c):x}' for c in e if ord(c) != 0xFE0F)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def render(cp):
    # weserv rasterizes the Twemoji SVG at 256px (sharp at any node size).
    for url in (
        f"https://images.weserv.nl/?url=cdn.jsdelivr.net/gh/jdecked/twemoji@15.1.0/assets/svg/{cp}.svg&w=256&h=256&output=png",
        f"https://images.weserv.nl/?url=cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/svg/{cp}.svg&w=256&h=256&output=png",
    ):
        try:
            data = fetch(url)
            if data[:8] == b"\x89PNG\r\n\x1a\n":
                return data
        except Exception as ex:
            print("  fetch fail", cp, ex)
    return None


def download_icons():
    os.makedirs(IC_DIR, exist_ok=True)
    os.makedirs(PH_DIR, exist_ok=True)
    ok = fail = 0
    for slug, lms in C.items():
        for (icon, emoji, *_rest) in lms:
            dst = os.path.join(IC_DIR, f"{slug}-{icon}.png")
            if not os.path.exists(dst):
                data = render(codepoints(emoji))
                if data is None:
                    print("MISS", slug, icon, emoji)
                    fail += 1
                    continue
                with open(dst, "wb") as f:
                    f.write(data)
                ok += 1
                time.sleep(0.15)
            # Photo placeholder shares the art until a real photo is uploaded.
            pdst = os.path.join(PH_DIR, f"{slug}-{icon}.jpg")
            if os.path.exists(dst) and not os.path.exists(pdst):
                shutil.copy(dst, pdst)
    print(f"icons: downloaded {ok}, missing {fail}")


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def inject_dart():
    p = os.path.join(ROOT, "lib", "core", "constants", "cities.dart")
    src = open(p, encoding="utf-8").read()
    if "'shanghai': [" in src:
        print("cities.dart already contains shanghai — skipped injection")
        return
    out = []
    for slug, lms in C.items():
        out.append(f"  '{slug}': [")
        for (icon, _e, nt, ne, dt, de) in lms:
            out.append(
                f"    Landmark(icon: '{icon}', photo: '{icon}', nameTr: '{esc(nt)}', "
                f"nameEn: '{esc(ne)}', descTr: '{esc(dt)}', descEn: '{esc(de)}'),")
        out.append("  ],")
    dart = "\n".join(out) + "\n"
    marker = "  'beijing': ["
    assert marker in src, "beijing marker not found"
    src = src.replace(marker, dart + marker, 1)
    open(p, "w", encoding="utf-8").write(src)
    print(f"cities.dart updated with {len(C)} L2 cities")


def main():
    # Within-city emoji uniqueness guard (identical side-by-side icons = bug).
    for slug, lms in C.items():
        seen = {}
        for (icon, emoji, *_r) in lms:
            if emoji in seen:
                raise SystemExit(f"DUP emoji {emoji} in {slug}: {seen[emoji]} & {icon}")
            seen[emoji] = icon
    download_icons()
    inject_dart()


if __name__ == "__main__":
    main()
