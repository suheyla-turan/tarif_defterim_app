import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  bool get isTurkish => locale.languageCode == 'tr';

  // Ana Sayfa
  String get appName => 'TARİF DEFTERİM';
  String get welcome => isTurkish ? 'Hoş geldin' : 'Welcome';
  String get categories => isTurkish ? 'Kategoriler' : 'Categories';
  String get meals => isTurkish ? 'Yemekler' : 'Meals';
  String get desserts => isTurkish ? 'Tatlılar' : 'Desserts';
  String get drinks => isTurkish ? 'İçecekler' : 'Drinks';
  String get favorites => isTurkish ? 'Beğendiklerim' : 'My Favorites';
  String get shoppingList => isTurkish ? 'Alışveriş Listem' : 'My Shopping List';
  String get myRecipes => isTurkish ? 'Tariflerim' : 'My Recipes';

  // Genel
  String get search => isTurkish ? 'Ara' : 'Search';
  String get settings => isTurkish ? 'Ayarlar' : 'Settings';
  String get profile => isTurkish ? 'Profil' : 'Profile';
  String get back => isTurkish ? 'Geri' : 'Back';
  String get save => isTurkish ? 'Kaydet' : 'Save';
  String get cancel => isTurkish ? 'İptal' : 'Cancel';
  String get delete => isTurkish ? 'Sil' : 'Delete';
  String get edit => isTurkish ? 'Düzenle' : 'Edit';
  String get add => isTurkish ? 'Ekle' : 'Add';
  String get close => isTurkish ? 'Kapat' : 'Close';
  String get confirm => isTurkish ? 'Onayla' : 'Confirm';
  String get loading => isTurkish ? 'Yükleniyor...' : 'Loading...';
  String get error => isTurkish ? 'Hata' : 'Error';
  String get success => isTurkish ? 'Başarılı' : 'Success';

  // Profil
  String get firstName => isTurkish ? 'İsim' : 'First Name';
  String get lastName => isTurkish ? 'Soyisim' : 'Last Name';
  String get email => isTurkish ? 'E-posta' : 'Email';
  String get signOut => isTurkish ? 'Çıkış Yap' : 'Sign Out';
  String get deleteAccount => isTurkish ? 'Oturumu Sil' : 'Delete Account';
  String get signOutConfirm => isTurkish ? 'Oturumunuzu kapatmak istediğinize emin misiniz?' : 'Are you sure you want to sign out?';
  String get deleteAccountConfirm => isTurkish ? 'Hesabınızı ve tüm verilerinizi kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.' : 'Are you sure you want to permanently delete your account and all your data? This action cannot be undone.';
  String get accountDeleted => isTurkish ? 'Hesap silindi' : 'Account deleted';

  // Ayarlar
  String get language => isTurkish ? 'Dil' : 'Language';
  String get theme => isTurkish ? 'Tema' : 'Theme';
  String get turkish => isTurkish ? 'Türkçe' : 'Turkish';
  String get english => isTurkish ? 'English' : 'English';
  String get light => isTurkish ? 'Açık' : 'Light';
  String get dark => isTurkish ? 'Karanlık' : 'Dark';
  String get systemDefault => isTurkish ? 'Varsayılan' : 'System Default';
  String get faq => isTurkish ? 'Sık Sorulan Sorular' : 'Frequently Asked Questions';
  String get about => isTurkish ? 'Hakkında' : 'About';
  String get support => isTurkish ? 'Destek' : 'Support';
  String get feedback => isTurkish ? 'Geribildirim' : 'Feedback';
  String get faqContent => isTurkish ? 'SSS içeriği buraya gelecek.\n\nUygulama hakkında sık sorulan sorular ve cevapları burada yer alacak.' : 'FAQ content will be here.\n\nFrequently asked questions and answers about the app will be here.';
  String get aboutContent => isTurkish ? 'Tarif Defterim\n\nVersiyon: 1.0.0\n\nTariflerinizi kaydedin, paylaşın ve keşfedin.' : 'My Recipe Book\n\nVersion: 1.0.0\n\nSave, share and discover recipes.';
  String get supportContent => isTurkish ? 'Sorularınız, önerileriniz veya geri bildirimleriniz için:\n\nE-posta: destek@tarifdefterim.com\n\nGeri bildirimleriniz bizim için çok değerli!' : 'For your questions, suggestions or feedback:\n\nEmail: support@myrecipebook.com\n\nYour feedback is very valuable to us!';
  
  // FAQ
  String get faqQuestion1 => isTurkish ? 'Uygulamayı nasıl kullanabilirim?' : 'How can I use the app?';
  String get faqAnswer1 => isTurkish 
      ? 'Uygulamayı kullanmak için önce kayıt olmanız gerekiyor. Kayıt olduktan sonra tarif ekleyebilir, mevcut tarifleri görüntüleyebilir, favorilerinize ekleyebilir ve alışveriş listesi oluşturabilirsiniz.'
      : 'To use the app, you first need to register. After registering, you can add recipes, view existing recipes, add them to your favorites, and create shopping lists.';
  
  String get faqQuestion2 => isTurkish ? 'Tarif nasıl eklerim?' : 'How do I add a recipe?';
  String get faqAnswer2 => isTurkish
      ? 'Ana sayfadan "Tariflerim" bölümüne gidin ve "Yeni Tarif" butonuna tıklayın. Tarif bilgilerini doldurun, malzemeleri ve adımları ekleyin, görsel yükleyin ve kaydedin.'
      : 'Go to "My Recipes" from the home page and click the "New Recipe" button. Fill in the recipe information, add ingredients and steps, upload images, and save.';
  
  String get faqQuestion3 => isTurkish ? 'Alışveriş listesi nasıl oluşturulur?' : 'How is a shopping list created?';
  String get faqAnswer3 => isTurkish
      ? 'Tarif detay sayfasında "Alışverişe ekle" butonuna tıklayarak tarifin malzemelerini alışveriş listesine ekleyebilirsiniz. Birden fazla tarif ekleyerek birleştirilmiş liste oluşturabilirsiniz.'
      : 'You can add recipe ingredients to your shopping list by clicking the "Add to Shopping List" button on the recipe detail page. You can create a merged list by adding multiple recipes.';
  
  String get faqQuestion4 => isTurkish ? 'Çırak (AI Asistanı) nedir?' : 'What is the Assistant (AI Assistant)?';
  String get faqAnswer4 => isTurkish
      ? 'Çırak, sesli komutlarla tarifleri dinlemenize ve yönetmenize yardımcı olan AI asistanıdır. Yemek yaparken elleriniz serbest kalır ve tarifleri sesli olarak dinleyebilirsiniz.'
      : 'The Assistant is an AI assistant that helps you listen to and manage recipes with voice commands. Your hands stay free while cooking and you can listen to recipes out loud.';
  
  String get faqQuestion5 => isTurkish ? 'Hesabımı nasıl silebilirim?' : 'How can I delete my account?';
  String get faqAnswer5 => isTurkish
      ? 'Profil sayfasından "Hesabı Sil" seçeneğini seçebilirsiniz. Bu işlem tüm verilerinizi kalıcı olarak silecektir ve geri alınamaz.'
      : 'You can select "Delete Account" from the profile page. This action will permanently delete all your data and cannot be undone.';
  
  // Support
  String get supportDescription => isTurkish
      ? 'Sorularınız, sorunlarınız veya yardıma ihtiyacınız varsa lütfen aşağıdaki formu doldurun. Size en kısa sürede dönüş yapacağız.'
      : 'If you have questions, problems, or need help, please fill out the form below. We will get back to you as soon as possible.';
  String get subject => isTurkish ? 'Konu' : 'Subject';
  String get subjectHint => isTurkish ? 'Örn: Uygulama hatası' : 'E.g: App error';
  String get message => isTurkish ? 'Mesaj' : 'Message';
  String get messageHint => isTurkish ? 'Sorununuzu veya sorunuzu detaylı olarak açıklayın...' : 'Please describe your problem or question in detail...';
  String get messageMinLength => isTurkish ? 'Mesaj en az 10 karakter olmalıdır' : 'Message must be at least 10 characters';
  String get submit => isTurkish ? 'Gönder' : 'Submit';
  String get supportSubmitted => isTurkish ? 'Destek mesajınız gönderildi. En kısa sürede size dönüş yapacağız.' : 'Your support message has been sent. We will get back to you as soon as possible.';
  
  // Feedback
  String get feedbackDescription => isTurkish
      ? 'Uygulamamızı geliştirmemize yardımcı olun! Görüşleriniz, önerileriniz ve geribildirimleriniz bizim için çok değerli.'
      : 'Help us improve our app! Your opinions, suggestions and feedback are very valuable to us.';
  String get feedbackHint => isTurkish ? 'Görüşlerinizi, önerilerinizi veya geribildirimlerinizi yazın...' : 'Write your opinions, suggestions or feedback...';
  String get feedbackMinLength => isTurkish ? 'Geribildirim en az 10 karakter olmalıdır' : 'Feedback must be at least 10 characters';
  String get feedbackSubmitted => isTurkish ? 'Geribildiriminiz gönderildi. Teşekkür ederiz!' : 'Your feedback has been submitted. Thank you!';
  String get rating => isTurkish ? 'Değerlendirme' : 'Rating';

  // Tarif Detay
  String get recipeDetails => isTurkish ? 'Tarif Detayları' : 'Recipe Details';
  String get type => isTurkish ? 'Tür' : 'Type';
  String get subType => isTurkish ? 'Alt Tür' : 'Sub Type';
  String get likes => isTurkish ? 'Beğeni' : 'Likes';
  String get description => isTurkish ? 'Açıklama' : 'Description';
  String get ingredients => isTurkish ? 'Malzemeler' : 'Ingredients';
  String get steps => isTurkish ? 'Adımlar' : 'Steps';
  String get step => isTurkish ? 'Adım' : 'Step';
  String get addToShoppingList => isTurkish ? 'Alışverişe ekle' : 'Add to Shopping List';
  String get addedToShoppingList => isTurkish ? 'Alışveriş listesine eklendi' : 'Added to shopping list';
  String get like => isTurkish ? 'Beğen' : 'Like';
  String get unlike => isTurkish ? 'Beğenmekten vazgeç' : 'Unlike';
  String get vegan => isTurkish ? 'Vegan' : 'Vegan';
  String get diet => isTurkish ? 'Diyet' : 'Diet';
  String get portion => isTurkish ? 'Porsiyon' : 'Portion';
  String get portionCount => isTurkish ? 'Porsiyon sayısı' : 'Portion Count';
  String get apply => isTurkish ? 'Uygula' : 'Apply';
  String get cirak => isTurkish ? 'Çırak' : 'Assistant';
  String get cirakListening => isTurkish ? 'Çırak: Dinliyor' : 'Assistant: Listening';
  String get voiceCommandUnavailable => isTurkish ? 'Sesli komut kullanılamıyor' : 'Voice command unavailable';
  String get voiceCommandActive => isTurkish ? 'Sesli komut aktif. "Başlat", "Durdur", "Devam" diyebilirsiniz.' : 'Voice command active. You can say "Start", "Stop", "Continue".';

  // Alışveriş Listesi
  String get myShoppingList => isTurkish ? 'Alışveriş Listem' : 'My Shopping List';
  String get addedRecipes => isTurkish ? 'Eklenen Tarifler' : 'Added Recipes';
  String get listItems => isTurkish ? 'Liste Ürünler' : 'List Items';
  String get mergedList => isTurkish ? 'Tüm tariflerden birleştirilmiş liste' : 'Merged list from all recipes';
  String get removeRecipeFromList => isTurkish ? 'Tarifi Listeden Çıkar' : 'Remove Recipe from List';
  String get removeRecipeConfirm => isTurkish ? 'tarifini listeden çıkarmak istediğinize emin misiniz?' : 'Are you sure you want to remove this recipe from the list?';
  String get remove => isTurkish ? 'Çıkar' : 'Remove';
  String get emptyList => isTurkish ? 'Liste boş.' : 'List is empty.';
  String get items => isTurkish ? 'kalem' : 'items';

  // Kategoriler
  String get subCategories => isTurkish ? 'Alt Kategoriler' : 'Sub Categories';
  String get mainDish => isTurkish ? 'Ana Yemek' : 'Main Dish';
  String get appetizer => isTurkish ? 'Meze' : 'Appetizer';
  String get soup => isTurkish ? 'Çorba' : 'Soup';
  String get salad => isTurkish ? 'Salata' : 'Salad';
  String get pastry => isTurkish ? 'Hamur İşi' : 'Pastry';
  String get milky => isTurkish ? 'Sütlü' : 'Milky';
  String get syrupy => isTurkish ? 'Şerbetli' : 'Syrupy';
  String get cake => isTurkish ? 'Kek & Pasta' : 'Cake & Pastry';
  String get cookie => isTurkish ? 'Kurabiye' : 'Cookie';
  String get hot => isTurkish ? 'Sıcak' : 'Hot';
  String get cold => isTurkish ? 'Soğuk' : 'Cold';
  String get smoothie => isTurkish ? 'Smoothie' : 'Smoothie';
  String get allRecipes => isTurkish ? 'Tüm Tarifler' : 'All Recipes';
  String get noRecipesInCategory => isTurkish ? 'Bu kategoride henüz tarif yok' : 'No recipes in this category yet';
  String get addFirstRecipe => isTurkish ? 'İlk tarifi sen ekle!' : 'Add the first recipe!';
  String get searchInCategory => isTurkish ? 'Kategori İçinde Ara' : 'Search in Category';
  String get searchRecipe => isTurkish ? 'Tarif ara...' : 'Search recipe...';
  String get clear => isTurkish ? 'Temizle' : 'Clear';

  // Tarif Ekle
  String get addRecipe => isTurkish ? 'Yeni Tarif' : 'New Recipe';
  String get title => isTurkish ? 'Başlık' : 'Title';
  String get required => isTurkish ? 'Zorunlu' : 'Required';
  String get optional => isTurkish ? 'Opsiyonel' : 'Optional';
  String get country => isTurkish ? 'Ülke' : 'Country';
  String get portionField => isTurkish ? 'Porsiyon' : 'Portion';
  String get portionExample => isTurkish ? 'Örn: 4' : 'E.g: 4';
  String get validNumber => isTurkish ? 'Geçerli bir sayı girin' : 'Enter a valid number';
  String get addIngredient => isTurkish ? 'Malzeme ekle' : 'Add Ingredient';
  String get addStep => isTurkish ? 'Adım ekle' : 'Add Step';
  String get ingredient => isTurkish ? 'Malzeme' : 'Ingredient';
  String get saving => isTurkish ? 'Kaydediliyor...' : 'Saving...';
  String get recipeAdded => isTurkish ? 'Tarif eklendi' : 'Recipe added';
  String get imagesUploadFailed => isTurkish ? 'Görseller yüklenemedi, tarif görselsiz kaydediliyor' : 'Images failed to upload, saving recipe without images';
  String get selectImage => isTurkish ? 'Görsel ekle' : 'Add Image';
  String get fromGallery => isTurkish ? 'Galeriden Seç' : 'Select from Gallery';
  String get fromCamera => isTurkish ? 'Kamera' : 'Camera';

  // Beğendiklerim
  String get myFavorites => isTurkish ? 'Beğendiklerim' : 'My Favorites';
  String get noFavorites => isTurkish ? 'Henüz beğendiğin bir tarif yok.' : 'You haven\'t liked any recipes yet.';

  // Tariflerim
  String get myRecipesTitle => isTurkish ? 'Tariflerim' : 'My Recipes';
  String get noRecipes => isTurkish ? 'Henüz tarif yok.' : 'No recipes yet.';
  String get addFirstRecipeButton => isTurkish ? 'İlk Tarifini Ekle' : 'Add Your First Recipe';
  String get deleteRecipe => isTurkish ? 'Tarifi Sil' : 'Delete Recipe';
  String get deleteRecipeConfirm => isTurkish ? 'tarifini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.' : 'Are you sure you want to delete this recipe? This action cannot be undone.';
  String get recipeDeleted => isTurkish ? 'Tarif silindi' : 'Recipe deleted';

  // Arama
  String get searchPlaceholder => isTurkish ? 'örn. aradığım...' : 'e.g. what I\'m looking for...';
  String get searchHistory => isTurkish ? 'Geçmiş Aramalar' : 'Search History';
  String get searchHistoryEmpty => isTurkish ? 'Arama geçmişi boş' : 'Search history is empty';
  String get noResults => isTurkish ? 'Sonuç yok' : 'No results';
  String get searchTitleContent => isTurkish ? 'Başlık, içerik, malzeme...' : 'Title, content, ingredient...';

  // Hata Mesajları
  String get sessionRequired => isTurkish ? 'Oturum açmanız gerekiyor' : 'You need to sign in';
  String get somethingWentWrong => isTurkish ? 'Bir hata oluştu.' : 'Something went wrong.';
  String get recipesLoadFailed => isTurkish ? 'Tarifler yüklenemedi' : 'Failed to load recipes';

  // Onboarding
  String get onboardingWelcome => isTurkish ? 'Hoş Geldin!' : 'Welcome!';
  String get onboardingWelcomeDesc => isTurkish 
      ? 'Tariflerini kolayca kaydet, paylaş ve keşfet. Yemek yapmayı daha eğlenceli hale getir.'
      : 'Easily save, share and discover recipes. Make cooking more fun.';
  String get onboardingRecipes => isTurkish ? 'Kendine Özel Defter' : 'Your Personal Recipe Book';
  String get onboardingRecipesDesc => isTurkish
      ? 'Favori tariflerini tek bir yerde topla. Kategorilere göre düzenle ve kolayca bul.'
      : 'Gather your favorite recipes in one place. Organize by categories and find them easily.';
  String get onboardingShopping => isTurkish ? 'Akıllı Alışveriş Listesi' : 'Smart Shopping List';
  String get onboardingShoppingDesc => isTurkish
      ? 'Tariflerinden otomatik alışveriş listesi oluştur. Hiçbir malzemeyi unutma!'
      : 'Automatically create shopping lists from your recipes. Never forget an ingredient!';
  String get onboardingAI => isTurkish ? 'AI Asistanı Çırak' : 'AI Assistant Chef';
  String get onboardingAIDesc => isTurkish
      ? 'Sesli komutlarla tarifleri dinle ve yönet. Yemek yaparken ellerin serbest!'
      : 'Listen and manage recipes with voice commands. Keep your hands free while cooking!';
  String get onboardingReady => isTurkish ? 'Hazırsan Başlayalım!' : 'Ready to Start!';
  String get onboardingReadyDesc => isTurkish
      ? 'Hemen kayıt ol veya giriş yap. Tarif dünyasına adım at!'
      : 'Sign up or log in now. Step into the world of recipes!';
  String get onboardingSkip => isTurkish ? 'Atla' : 'Skip';
  String get onboardingNext => isTurkish ? 'İleri' : 'Next';
  String get onboardingGetStarted => isTurkish ? 'Başlayalım' : 'Get Started';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['tr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Provider for current locale
final localeProvider = Provider<Locale>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.language == AppLanguage.english
      ? const Locale('en', 'US')
      : const Locale('tr', 'TR');
});

