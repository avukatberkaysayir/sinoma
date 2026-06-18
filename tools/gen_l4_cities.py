# Injects the HSK-4 (Level 4) unit-city Landmark data into cities.dart. Five L4
# unit cities (xuzhou, jiaxing, lishui, ganzhou, putian) already have landmarks
# from the original set, so only the other 19 are added here. Icon art comes
# from tools/fetch_all_icons.py (globally-unique icons8 set) — none downloaded
# here. After: extend fetch_all_icons.py, then regenerate the packs.
import os, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

C = {
 'shenzhen': [
  ('skyscraper', 'Gökdelenler', 'Skyscrapers', "Bir balıkçı köyünden 40 yılda yükselen gökdelen ormanı, Çin reformunun mucizesidir.", "A forest of skyscrapers risen from a fishing village in 40 years — the miracle of China's reform."),
  ('chip', 'Teknoloji Şehri', 'Tech City', "Huaqiangbei elektronik çarşısı ve dev teknoloji şirketleriyle Shenzhen 'Çin'in Silikon Vadisi'dir.", "With the Huaqiangbei electronics market and tech giants, Shenzhen is 'China's Silicon Valley'."),
  ('miniature', 'Dünya Penceresi', 'Window of the World', "Dünyanın ünlü yapılarının minyatürlerini bir araya getiren tema parkı şehrin simgesidir.", "A theme park gathering miniatures of the world's famous landmarks is a city icon."),
  ('mangrove', 'Shenzhen Körfezi', 'Shenzhen Bay', "Mangrov ormanlı körfez, göçmen kuşların ve ak balıkçılların uğrağıdır.", "The mangrove-lined bay is a haven for migratory birds and egrets.")],
 'xian': [
  ('terracotta', 'Toprak Ordu', 'Terracotta Army', "İmparator Qin'in mezarını koruyan binlerce pişmiş toprak asker, dünyanın sekizinci harikası sayılır.", "Thousands of clay soldiers guarding Emperor Qin's tomb are called the eighth wonder of the world."),
  ('citywall', 'Şehir Suru', 'City Wall', "Çin'in en eksiksiz korunmuş Ming şehir suru, üzerinde bisikletle turlanır.", "China's best-preserved Ming city wall is toured by bicycle along its ramparts."),
  ('drumtower', 'Çan Kulesi', 'Bell Tower', "Şehrin tam merkezindeki Ming çan kulesi, eski başkentin kalbini simgeler.", "The Ming bell tower at the very centre marks the heart of the ancient capital."),
  ('roujiamo', 'Roujiamo', 'Chinese Burger', "Çıtır ekmeğe doldurulan baharatlı et 'roujiamo', İpek Yolu'nun ilk hamburgeridir.", "Spiced meat stuffed in crisp flatbread, 'roujiamo' is the Silk Road's original burger.")],
 'suzhou': [
  ('garden', 'Klasik Bahçeler', 'Classical Gardens', "Kayalık, havuz ve köşkleriyle ince tasarlanmış bahçeler UNESCO mirasıdır.", "Exquisitely designed with rockeries, ponds and pavilions, the gardens are UNESCO-listed."),
  ('watertown', 'Su Kasabası', 'Water Town', "Kanalları, taş köprüleri ve beyaz evleriyle Suzhou 'Doğu'nun Venedik'i'dir.", "With canals, stone bridges and white houses, Suzhou is the 'Venice of the East'."),
  ('embroidery', 'Su İşlemesi', 'Su Embroidery', "İki yüzü farklı işlenen ipek nakış, bin yıllık bir Suzhou zanaatıdır.", "Double-sided silk embroidery is a thousand-year-old Suzhou craft."),
  ('kunqu', 'Kunqu Operası', 'Kunqu Opera', "Tüm Çin operalarının anası sayılan zarif Kunqu, burada doğdu.", "The elegant Kunqu, regarded as the mother of all Chinese opera, was born here.")],
 'kunming': [
  ('stoneforest', 'Taş Orman', 'Stone Forest', "Milyonlarca yılda oyulan dev kireçtaşı sütunları, ürpertici bir taş labirenti oluşturur.", "Giant limestone pillars carved over millions of years form an eerie maze of stone."),
  ('springcity', 'Bahar Şehri', 'Spring City', "Yıl boyu ılıman iklimiyle Kunming, çiçeklerin hiç solmadığı 'bahar şehri'dir.", "With a mild climate all year, Kunming is the 'spring city' where flowers never fade."),
  ('seagull', 'Kırmızı Gagalı Martılar', 'Black-Headed Gulls', "Her kış Sibirya'dan gelen binlerce martı, göl kıyısını beyaza boyar.", "Each winter thousands of gulls from Siberia turn the lakeshore white."),
  ('ricenoodle', 'Köprü Eriştesi', 'Crossing-Bridge Noodles', "Sıcak et suyuna masada eklenen ince pirinç eriştesi, Yunnan'ın imza yemeğidir.", "Thin rice noodles added to hot broth at the table are Yunnan's signature dish.")],
 'jinan': [
  ('spring', 'Pınarlar Şehri', 'City of Springs', "Yerden fışkıran 72 ünlü pınar, Jinan'a 'pınarlar şehri' adını verir.", "Seventy-two famous springs welling from the ground give Jinan its name, 'city of springs'."),
  ('daminglake', 'Daming Gölü', 'Daming Lake', "Söğüt ve nilüferlerle çevrili şehir gölü, pınar sularıyla beslenir.", "Ringed by willows and lotus, the city lake is fed by the springs."),
  ('buddhamountain', 'Bin Buda Dağı', 'Thousand-Buddha Mountain', "Yamaçlarına oyulmuş yüzlerce Buda figürüyle dağ, bir hac yeridir.", "With hundreds of Buddhas carved into its slopes, the mountain is a place of pilgrimage."),
  ('poet', 'Li Qingzhao', 'Poet Li Qingzhao', "Çin'in en büyük kadın şairi Li Qingzhao bu pınarlar şehrinde doğdu.", "China's greatest female poet, Li Qingzhao, was born in this city of springs.")],
 'ningbo': [
  ('library', 'Tianyi Kütüphanesi', 'Tianyi Pavilion', "450 yıllık Tianyi Ge, Asya'nın ayakta kalan en eski özel kütüphanesidir.", "The 450-year-old Tianyi Ge is Asia's oldest surviving private library."),
  ('port', 'Liman', 'Cargo Port', "Ningbo-Zhoushan, kargo hacmiyle dünyanın en yoğun limanıdır.", "Ningbo-Zhoushan is the world's busiest port by cargo tonnage."),
  ('tangyuan', 'Tangyuan', 'Glutinous Rice Balls', "Susam dolgulu pirinç unu topları 'tangyuan', şehrin tatlı imzasıdır.", "Sesame-filled glutinous rice balls, 'tangyuan', are the city's sweet signature."),
  ('seafood', 'Deniz Ürünleri', 'Seafood', "Doğu Çin Denizi'nin sarı kroker balığı ve yengeci yerel sofranın temelidir.", "Yellow croaker and crab from the East China Sea are the base of the local table.")],
 'shijiazhuang': [
  ('bridge', 'Zhaozhou Köprüsü', 'Zhaozhou Bridge', "1.400 yıllık taş kemer köprü, dünyanın en eski açık tympanonlu köprüsüdür.", "The 1,400-year-old stone arch is the world's oldest open-spandrel bridge."),
  ('clifftemple', 'Cangyan Dağı', 'Mount Cangyan', "Uçurumlar arasına asılı tapınak köprüsü, sayısız filme dekor oldu.", "The temple bridge suspended between cliffs has been the backdrop of countless films."),
  ('redbase', 'Xibaipo', 'Xibaipo Base', "Yeni Çin'in kuruluşunun planlandığı köy, 'kırmızı turizmin' kutsal durağıdır.", "The village where New China was planned is a sacred stop of 'red tourism'."),
  ('pharma', 'İlaç Şehri', 'Pharma City', "Çin'in en büyük ilaç üreticilerinden biri olan şehir, antibiyotik üssüdür.", "One of China's largest drug makers, the city is a hub of antibiotic production.")],
 'taiyuan': [
  ('jincitemple', 'Jinci Tapınağı', 'Jinci Temple', "Üç bin yıllık heykelleri ve pınarlarıyla Jinci, kuzey Çin'in en zarif tapınak bahçesidir.", "With three-thousand-year-old statues and springs, Jinci is north China's most graceful temple garden."),
  ('coalcart', 'Kömür Diyarı', 'Coal Land', "Shanxi'nin kömür yatakları Çin'in enerjisini besler; Taiyuan bu zenginliğin başkentidir.", "Shanxi's coal seams power China; Taiyuan is the capital of that wealth."),
  ('vinegar', 'Shanxi Sirkesi', 'Aged Vinegar', "Yıllandırılmış olgun sirke, Shanxi mutfağının vazgeçilmez ekşisidir.", "Mature aged vinegar is the essential sourness of Shanxi cuisine."),
  ('twinpagoda', 'İkiz Pagodalar', 'Twin Pagodas', "Şehrin simgesi olan iki sekizgen Ming pagodası, yan yana yükselir.", "Two octagonal Ming pagodas, the city's emblem, rise side by side.")],
 'hohhot': [
  ('lamatemple', 'Dazhao Tapınağı', 'Dazhao Temple', "Gümüş Buda heykeliyle ünlü Tibet Budist manastırı, şehrin manevi merkezidir.", "Famed for its silver Buddha, the Tibetan Buddhist monastery is the city's spiritual heart."),
  ('dairy', 'Süt Başkenti', 'Dairy Capital', "Çin'in en büyük süt markaları burada doğdu; şehir 'süt şehri' diye anılır.", "China's largest dairy brands were born here — the city is called the 'milk capital'."),
  ('wrestling', 'Moğol Güreşi', 'Mongolian Wrestling', "Naadam şenliğinin gözde yarışı boke güreşi, bozkır gücünün gösterisidir.", "Bökh wrestling, the highlight of the Naadam festival, is a display of steppe strength."),
  ('prairie', 'Bozkır', 'Grassland', "Şehrin ötesinde uzanan yeşil Moğol bozkırları, at ve sürülerle doludur.", "Beyond the city stretch the green Mongolian grasslands, full of horses and herds.")],
 'sanya': [
  ('resortbeach', 'Tropik Plaj', 'Tropical Beach', "Yalong Körfezi'nin pudra gibi kumları ve turkuaz suları Çin'in Hawaii'sidir.", "Yalong Bay's powdery sands and turquoise water are China's Hawaii."),
  ('guanyin', 'Nanshan Guanyin', 'Guanyin Statue', "Denizin üstünde yükselen 108 metrelik Guanyin heykeli, dünyanın en yüksek tanrıça heykellerindendir.", "Rising 108 m over the sea, the Guanyin statue is among the world's tallest goddess figures."),
  ('diving', 'Dalış', 'Diving', "Sıcak berrak suları ve mercan resifleriyle Sanya, Çin'in dalış cennetidir.", "With warm clear water and coral reefs, Sanya is China's diving paradise."),
  ('coconutdrink', 'Hindistan Cevizi', 'Coconut', "Tropik bahçelerden toplanan taze hindistan cevizi suyu, adanın serinliğidir.", "Fresh coconut water from tropical groves is the island's cool refreshment.")],
 'yangzhou': [
  ('slenderlake', 'İnce Batı Gölü', 'Slender West Lake', "Söğütleri ve beyaz köprüleriyle ince uzun göl, bir resim kadar zariftir.", "With willows and a white bridge, the slender lake is as graceful as a painting."),
  ('friedrice', 'Yangzhou Pilavı', 'Yangzhou Fried Rice', "Karides ve yumurtayla harmanlanan altın pilav, dünyaca ünlü bir klasiktir.", "Golden rice tossed with shrimp and egg is a world-famous classic."),
  ('morningtea', 'Sabah Çayı', 'Morning Tea', "Buğulama börek ve demli çayla yapılan zarif kahvaltı, Yangzhou'nun ritüelidir.", "An elegant breakfast of steamed buns and tea is Yangzhou's ritual."),
  ('gegarden', 'Ge Bahçesi', 'Ge Garden', "Dört mevsimi taşlarla canlandıran bambu bahçesi, klasik tasarımın başyapıtıdır.", "A bamboo garden evoking the four seasons in stone is a masterpiece of classical design.")],
 'weihai': [
  ('navalisland', 'Liugong Adası', 'Liugong Island', "Beiyang Donanması'nın üssü olan ada, modern Çin'in deniz tarihine tanıklık eder.", "Base of the Beiyang Fleet, the island witnesses modern China's naval history."),
  ('swan', 'Kuğu Gölü', 'Swan Lake', "Her kış Sibirya'dan gelen yüzlerce ötücü kuğu, kıyı lagününü süsler.", "Each winter hundreds of whooper swans from Siberia grace the coastal lagoon."),
  ('seacucumber', 'Deniz Hıyarı', 'Sea Cucumber', "Soğuk temiz sularda yetişen deniz hıyarı, şehrin en değerli deniz ürünüdür.", "Grown in cold clean waters, sea cucumber is the city's most prized seafood."),
  ('cape', "Çin'in Ucu", 'Cape of China', "Çin'in en doğu burnu, güneşin ülkeyi ilk selamladığı yerdir.", "China's easternmost cape is where the sun first greets the country.")],
 'handan': [
  ('taichi', 'Tai Chi', 'Tai Chi', "Yang ve Wu üsluplarının doğduğu Guangfu kasabası, taijiquan'ın memleketidir.", "Guangfu town, birthplace of the Yang and Wu styles, is the home of taijiquan."),
  ('congtai', 'Congtai Terası', 'Congtai Terrace', "Antik Zhao Krallığı'ndan kalan kerpiç teras, 2.000 yıllık tarihe bakar.", "An earthen terrace from the ancient Zhao kingdom looks over 2,000 years of history."),
  ('idiom', 'Deyim Başkenti', 'City of Idioms', "1.500'den fazla Çince deyim bu topraklarda doğdu; Handan 'deyimler şehri'dir.", "Over 1,500 Chinese idioms were born here — Handan is the 'city of idioms'."),
  ('ciporcelain', 'Cizhou Porseleni', 'Cizhou Ware', "Beyaz üstüne siyah desenli Cizhou porseleni, halk seramiğinin klasiğidir.", "Black-on-white Cizhou porcelain is a classic of folk ceramics.")],
 'daqing': [
  ('oilpump', 'Petrol Sahası', 'Oilfield', "Çin'in en büyük petrol sahası, başını eğip kaldıran kuyu pompalarıyla doludur.", "China's largest oilfield is dotted with nodding pumpjacks."),
  ('oilworker', 'Demir Adam', 'Iron Man', "Petrol işçisi kahraman Wang Jinxi'nin azmi, şehrin kuruluş ruhudur.", "The grit of oil-worker hero Wang Jinxi is the founding spirit of the city."),
  ('reedlake', 'Sulak Alan', 'Wetlands', "Petrol kuyuları arasındaki geniş sazlık gölleri, turna ve kuğulara yuva olur.", "Vast reedy lakes among the oil wells are home to cranes and swans."),
  ('hotspring', 'Kaplıca', 'Hot Spring', "Yer altından çıkan sıcak mineralli sular, soğuk kuzeyde şifalı bir mola sunar.", "Hot mineral waters from underground offer a healing break in the cold north.")],
 'zibo': [
  ('bbq', 'Zibo Mangalı', 'Zibo Barbecue', "İnce şişlerin küçük mangalda pişirilip ince pidelere sarıldığı barbekü, ülkeyi sardı.", "Skewers grilled on small braziers and wrapped in thin pancakes — a barbecue craze that swept the nation."),
  ('cuju', 'Cuju', 'Ancient Football', "Dünyanın en eski futbolu cuju, antik Qi başkenti Linzi'de oynanırdı.", "Cuju, the world's oldest form of football, was played in the ancient Qi capital of Linzi."),
  ('ceramic', 'Zibo Seramiği', 'Zibo Ceramics', "Bin yıllık ocaklarıyla şehir, kuzey Çin'in seramik merkezlerindendir.", "With thousand-year kilns, the city is a ceramics centre of north China."),
  ('glass', 'Liuli Camı', 'Colored Glaze', "Renkli erimiş camdan elde yapılan liuli sanatı, ışıkla parlayan bir zanaattır.", "Liuli, hand-made from coloured molten glass, is a craft that glows with light.")],
 'taian': [
  ('mounttai', 'Tai Dağı', 'Mount Tai', "Beş Kutsal Dağ'ın başı Tai, imparatorların göğe kurban sunduğu en kutsal zirvedir.", "Chief of the Five Sacred Mountains, Tai is the holiest peak where emperors made offerings to heaven."),
  ('sunrise', 'Zirvede Gün Doğumu', 'Summit Sunrise', "Bulut denizi üstünde doğan güneşi izlemek, Tai Dağı'na çıkmanın baş ödülüdür.", "Watching the sun rise over a sea of clouds is the prize of climbing Mount Tai."),
  ('stonesteps', 'Yedi Bin Basamak', 'Stone Stairway', "Zirveye uzanan 7.000 taş basamak, hac yolunun fiziksel sınavıdır.", "The 7,000 stone steps to the summit are the physical trial of the pilgrim's path."),
  ('daitemple', 'Dai Tapınağı', 'Dai Temple', "Dağ eteğindeki görkemli tapınak, imparatorların Tai törenlerine hazırlandığı yerdi.", "The grand temple at the foot is where emperors prepared for the Tai rites.")],
 'lianyungang': [
  ('monkey', 'Maymun Kral Dağı', "Monkey King's Mountain", "'Batı'ya Yolculuk' destanının Maymun Kralı'nın evi Huaguoshan burada yükselir.", "Huaguoshan, home of the Monkey King of 'Journey to the West', rises here."),
  ('seaport', 'Deniz Limanı', 'Seaport', "İpek Yolu'nun doğu deniz kapısı, Avrasya demiryolunun Pasifik ucudur.", "The Silk Road's eastern sea gate is the Pacific end of the Eurasian rail bridge."),
  ('mountain', 'Yuntai Dağı', 'Mount Yuntai', "Sarp Yuntai zirveleri ve ormanlarıyla, Jiangsu'nun en yüksek dağıdır.", "With steep peaks and forests, Yuntai is the highest mountain in Jiangsu."),
  ('crystal', 'Kristal Diyarı', 'Crystal Land', "Yakın Donghai, dünyanın en büyük kuvars kristal pazarlarından birine ev sahipliği yapar.", "Nearby Donghai hosts one of the world's largest quartz crystal markets.")],
 'maanshan': [
  ('libai', 'Şair Li Bai', 'Poet Li Bai', "Çin'in en büyük şairi Li Bai'nin son durağı ve mezarı bu nehir kasabasıdır.", "The final stop and tomb of China's greatest poet, Li Bai, is in this river town."),
  ('steel', 'Çelik Şehri', 'Steel City', "Magang çelik kombinası, şehri Çin'in demir-çelik üslerinden biri yaptı.", "The Magang steelworks made the city one of China's iron-and-steel bases."),
  ('rivercliff', 'Caishiji Kayalığı', 'Caishiji Cliff', "Yangtze'ye dik inen kaya burnu, Li Bai efsanesinin geçtiği şiirsel manzaradır.", "The cliff plunging into the Yangtze is the poetic scene of the Li Bai legend."),
  ('moonwine', 'Ay ve Şarap', 'Moon & Wine', "Li Bai'nin dizelerindeki ay ve şarap, nehir kıyısı şenliklerinde hâlâ kutlanır.", "The moon and wine of Li Bai's verse are still celebrated at riverside festivals.")],
 'longyan': [
  ('tulou', 'Yongding Tulou', 'Yongding Earth Houses', "Dağlara serpilmiş dev yuvarlak Hakka kale-evleri UNESCO mirasıdır.", "Giant round Hakka fortress-homes scattered through the hills are UNESCO-listed."),
  ('redmeeting', 'Gutian Toplantısı', 'Gutian Meeting', "Kızıl Ordu'nun yön belirlediği tarihî toplantı bu köyde yapıldı.", "The historic meeting that set the Red Army's course was held in this village."),
  ('hakka', 'Hakka Kültürü', 'Hakka Culture', "Kuzeyden göçen Hakka halkı, kendine özgü dili ve mutfağını bu dağlarda yaşatır.", "The Hakka people, migrants from the north, keep their language and cuisine alive in these hills."),
  ('mountain', 'Guanzhi Dağı', 'Mount Guanzhi', "Kızıl kayalıkları ve berrak göletleriyle dağ, güney Fujian'ın doğa incisidir.", "With red cliffs and clear pools, the mountain is the natural pearl of southern Fujian.")],
}


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def main():
    p = os.path.join(ROOT, "lib", "core", "constants", "cities.dart")
    src = open(p, encoding="utf-8").read()
    if "'shenzhen': [" in src:
        print("cities.dart already contains shenzhen — skipped")
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
    print(f"cities.dart updated with {len(C)} L4 cities ({n} landmarks)")


if __name__ == "__main__":
    main()
