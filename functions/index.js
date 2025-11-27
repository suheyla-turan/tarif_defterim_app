// .env dosyasını yükle (varsa)
require('dotenv').config();

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');
admin.initializeApp();

// OpenAI API anahtarı (eğer kullanılacaksa)
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';

// AI tarif dönüştürme fonksiyonu
exports.transformRecipe = functions.https.onCall(async (data, context) => {
  // Kullanıcı kimlik doğrulaması kontrolü
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Kullanıcı girişi gerekli'
    );
  }

  const { recipe, transformType, targetPortions, currentPortions } = data;

  if (!recipe || !transformType) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Tarif ve dönüştürme tipi gerekli'
    );
  }

  try {
    let transformedRecipe;

    switch (transformType) {
      case 'vegan':
        transformedRecipe = await transformToVegan(recipe);
        break;
      case 'diet':
        transformedRecipe = await transformToDiet(recipe);
        break;
      case 'portion':
        transformedRecipe = await scalePortions(recipe, targetPortions || 1, currentPortions);
        break;
      default:
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Geçersiz dönüştürme tipi'
        );
    }

    return {
      success: true,
      transformedRecipe: transformedRecipe
    };
  } catch (error) {
    console.error('Transform error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Tarif dönüştürme hatası: ' + error.message
    );
  }
});

// Belirli bir tarif hakkında soru-cevap
exports.askRecipeQuestion = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Kullanıcı girişi gerekli'
    );
  }

  const { recipe, question, imageUrl } = data;

  if (!recipe || !question || typeof question !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Tarif ve soru gerekli'
    );
  }

  // OpenAI anahtarı yoksa basit, tarif bilgilerini özetleyen bir cevap ver
  if (!OPENAI_API_KEY) {
    const lines = [];
    lines.push(`Bu cevap akıllı asistan olmadan oluşturuldu, ama tarif bilgilerini özetleyebilirim.`);
    lines.push(`\nTarif: ${recipe.title || 'Bilinmeyen tarif'}`);
    if (recipe.portions) {
      lines.push(`Porsiyon: ${recipe.portions}`);
    }
    if (Array.isArray(recipe.ingredients)) {
      lines.push('\nMalzemeler:');
      recipe.ingredients.forEach((ing) => lines.push(`- ${ing}`));
    }
    if (Array.isArray(recipe.steps)) {
      lines.push('\nAdımlar:');
      recipe.steps.forEach((step, idx) => lines.push(`${idx + 1}. ${step}`));
    }
    return { answer: lines.join('\n') };
  }

  try {
    const ingredientsText = Array.isArray(recipe.ingredients)
      ? recipe.ingredients.map((i) => `- ${i}`).join('\n')
      : '';
    const stepsText = Array.isArray(recipe.steps)
      ? recipe.steps.map((s, idx) => `${idx + 1}. ${s}`).join('\n')
      : '';

    const systemPrompt =
      'Sen deneyimli bir Türk şef ve beslenme uzmanısın. Kullanıcı sadece belirli bir tarif hakkında sorular soracak.' +
      ' YALNIZCA verilen tarif bilgilerini (başlık, açıklama, malzemeler, adımlar, porsiyon, ana/alt tür) kullan.' +
      ' Tahmin yürütmen gerektiğinde bunu açıkça belirt, uydurma veri ekleme.' +
      ' Cevaplarını kısa, net ve konuşma dilinde, TÜRKÇE olarak ver.';

    const userPrompt = `Tarif bilgileri:
Başlık: ${recipe.title || ''}
Ana tür: ${recipe.mainType || ''}
Alt tür: ${recipe.subType || ''}
Porsiyon: ${recipe.portions || ''}
Açıklama: ${recipe.description || ''}

Malzemeler:
${ingredientsText}

Adımlar:
${stepsText}

Kullanıcının sorusu:
${question}

Lütfen sadece bu tarif bağlamında cevap ver.

Eğer bir fotoğraf bağlantısı verilmişse, bu fotoğraf tarifle ilgili olabilir. Fotoğrafı yorumlarken yine sadece tarifin bağlamında kalmaya çalış:
${imageUrl ? imageUrl : '(fotoğraf yok)'} 
`;

    const userContent = imageUrl
      ? [
          { type: 'text', text: userPrompt },
          { type: 'image_url', image_url: { url: imageUrl } },
        ]
      : userPrompt;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userContent },
        ],
        temperature: 0.4,
        max_tokens: 800,
      }),
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.statusText}`);
    }

    const result = await response.json();
    const content = result.choices?.[0]?.message?.content || '';

    if (!content.trim()) {
      throw new Error('Boş cevap döndü');
    }

    return { answer: content.trim() };
  } catch (error) {
    console.error('askRecipeQuestion error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Tarif sorusu yanıtlanırken bir hata oluştu: ' + error.message
    );
  }
});

// Vegan dönüştürme (OpenAI ile)
async function transformToVegan(recipe) {
  if (!OPENAI_API_KEY) {
    return transformToVeganFallback(recipe);
  }

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'Sen bir vegan tarif uzmanısın. Verilen tarifi vegan versiyonuna çevir. Hayvansal ürünleri uygun bitkisel alternatiflerle değiştir. Malzemeleri ve adımları güncelle. Sadece JSON formatında döndür.'
          },
          {
            role: 'user',
            content: `Şu tarifi vegan versiyonuna çevir:\n\nBaşlık: ${recipe.title}\n\nMalzemeler:\n${recipe.ingredients.join('\n')}\n\nAdımlar:\n${recipe.steps.join('\n')}\n\nJSON formatında şu yapıda döndür: {"title": "...", "ingredients": [...], "steps": [...]}`
          }
        ],
        temperature: 0.7,
        max_tokens: 2000
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.statusText}`);
    }

    const data = await response.json();
    const content = data.choices[0].message.content;
    
    // JSON'u parse et
    let aiResult;
    try {
      // JSON kod bloğu varsa temizle
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        aiResult = JSON.parse(jsonMatch[0]);
      } else {
        aiResult = JSON.parse(content);
      }
    } catch (e) {
      console.error('JSON parse error:', e);
      return transformToVeganFallback(recipe);
    }

    return {
      ...recipe,
      title: aiResult.title || `${recipe.title} (Vegan)`,
      ingredients: aiResult.ingredients || recipe.ingredients,
      steps: aiResult.steps || recipe.steps,
      keywords: [...(recipe.keywords || []), 'vegan']
    };
  } catch (error) {
    console.error('OpenAI transform error:', error);
    return transformToVeganFallback(recipe);
  }
}

// Fallback vegan dönüştürme
function transformToVeganFallback(recipe) {
  const replacements = {
    'süt': 'bitkisel süt',
    'yoğurt': 'bitkisel yoğurt',
    'peynir': 'vegan peynir',
    'tereyağı': 'zeytinyağı',
    'yumurta': 'keten tohumu yumurtası',
    'bal': 'agave şurubu',
    'et': 'bitkisel protein',
    'tavuk': 'nohut/karnabahar',
    'kıyma': 'soya kıyması',
  };

  const transformed = { ...recipe };
  
  transformed.ingredients = recipe.ingredients.map(ing => {
    let result = ing.toLowerCase();
    for (const [key, value] of Object.entries(replacements)) {
      result = result.replace(new RegExp(key, 'gi'), value);
    }
    return result;
  });

  transformed.steps = recipe.steps.map(step => {
    let result = step.toLowerCase();
    for (const [key, value] of Object.entries(replacements)) {
      result = result.replace(new RegExp(key, 'gi'), value);
    }
    return result;
  });

  transformed.title = `${recipe.title} (Vegan)`;
  transformed.keywords = [...(recipe.keywords || []), 'vegan'];

  return transformed;
}

// Diyet dönüştürme (OpenAI ile)
async function transformToDiet(recipe) {
  if (!OPENAI_API_KEY) {
    return transformToDietFallback(recipe);
  }

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'Sen bir diyetisyen ve sağlıklı yemek uzmanısın. Verilen tarifi daha sağlıklı ve düşük kalorili versiyonuna çevir. Şeker, yağ ve kalori miktarlarını azalt, sağlıklı alternatifler öner. Malzemeleri ve adımları güncelle. Sadece JSON formatında döndür.'
          },
          {
            role: 'user',
            content: `Şu tarifi diyet versiyonuna çevir:\n\nBaşlık: ${recipe.title}\n\nMalzemeler:\n${recipe.ingredients.join('\n')}\n\nAdımlar:\n${recipe.steps.join('\n')}\n\nJSON formatında şu yapıda döndür: {"title": "...", "ingredients": [...], "steps": [...]}`
          }
        ],
        temperature: 0.7,
        max_tokens: 2000
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.statusText}`);
    }

    const data = await response.json();
    const content = data.choices[0].message.content;
    
    let aiResult;
    try {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        aiResult = JSON.parse(jsonMatch[0]);
      } else {
        aiResult = JSON.parse(content);
      }
    } catch (e) {
      console.error('JSON parse error:', e);
      return transformToDietFallback(recipe);
    }

    return {
      ...recipe,
      title: aiResult.title || `${recipe.title} (Diyet)`,
      ingredients: aiResult.ingredients || recipe.ingredients,
      steps: aiResult.steps || recipe.steps,
      keywords: [...(recipe.keywords || []), 'diyet']
    };
  } catch (error) {
    console.error('OpenAI transform error:', error);
    return transformToDietFallback(recipe);
  }
}

// Fallback diyet dönüştürme
function transformToDietFallback(recipe) {
  const unhealthy = {
    'şeker': 'eritritol/stevia',
    'tereyağı': 'zeytinyağı',
    'kızart': 'fırınla',
  };

  const transformed = { ...recipe };

  transformed.ingredients = recipe.ingredients.map(ing => {
    let result = ing;
    for (const [key, value] of Object.entries(unhealthy)) {
      result = result.replace(new RegExp(key, 'gi'), value);
    }
    return result;
  });

  transformed.steps = recipe.steps.map(step => {
    let result = step;
    for (const [key, value] of Object.entries(unhealthy)) {
      result = result.replace(new RegExp(key, 'gi'), value);
    }
    return result;
  });

  transformed.title = `${recipe.title} (Diyet)`;
  transformed.keywords = [...(recipe.keywords || []), 'diyet'];

  return transformed;
}

// Porsiyon ölçeklendirme (OpenAI ile daha akıllı)
async function scalePortions(recipe, targetPortions, currentPortions) {
  if (targetPortions <= 0) targetPortions = 1;
  // Mevcut porsiyon bilgisini kullan (yoksa tariften çıkarmaya çalış veya 1 varsay)
  const current = currentPortions || recipe.portions || 1;

  if (!OPENAI_API_KEY || targetPortions === current) {
    return scalePortionsFallback(recipe, targetPortions, current);
  }

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'Sen deneyimli bir aşçısın. Verilen tarifin malzeme miktarlarını mevcut porsiyondan hedef porsiyona göre ölçekle. ÖNEMLİ: Bazı malzemeler porsiyon sayısı artsa bile sabit kalmalıdır veya çok az artmalıdır:\n- Tuz, karabiber, kırmızıbiber gibi baharatlar: Genellikle aynı kalır veya çok az artar\n- Karbonat, kabartma tozu gibi mayalayıcılar: Orantılı artmaz, aynı kalır\n- Vanilya, limon suyu gibi lezzet vericiler: Aynı kalır veya çok az artar\n- Pişirme süreleri: Değişmez\nAna malzemeleri (un, et, sebze, sıvılar vb.) orantılı olarak ölçekle. Baharatları ve lezzet vericileri akıllıca koru. Sadece JSON formatında döndür.'
          },
          {
            role: 'user',
            content: `Şu tarif şu anda ${current} porsiyon için. Bunu ${targetPortions} porsiyon için ölçekle:\n\nBaşlık: ${recipe.title}\n\nMalzemeler:\n${recipe.ingredients.join('\n')}\n\nÖNEMLİ: Baharatları (tuz, karabiber, vb.), mayalayıcıları ve lezzet vericileri sabit tut veya çok az artır. Ana malzemeleri orantılı olarak ölçekle.\n\nJSON formatında şu yapıda döndür: {"title": "...", "ingredients": [...]}`
          }
        ],
        temperature: 0.3,
        max_tokens: 1500
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.statusText}`);
    }

    const data = await response.json();
    const content = data.choices[0].message.content;
    
    let aiResult;
    try {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        aiResult = JSON.parse(jsonMatch[0]);
      } else {
        aiResult = JSON.parse(content);
      }
    } catch (e) {
      console.error('JSON parse error:', e);
      return scalePortionsFallback(recipe, targetPortions, current);
    }

    return {
      ...recipe,
      title: aiResult.title || `${recipe.title} (${targetPortions} porsiyon)`,
      ingredients: aiResult.ingredients || recipe.ingredients,
      portions: targetPortions,
      keywords: [...(recipe.keywords || []), 'porsiyon']
    };
  } catch (error) {
    console.error('OpenAI scale error:', error);
    return scalePortionsFallback(recipe, targetPortions, current);
  }
}

// Fallback porsiyon ölçeklendirme
function scalePortionsFallback(recipe, targetPortions, currentPortions) {
  // Mevcut porsiyon bilgisini kullan (yoksa 1 varsay)
  const current = currentPortions || recipe.portions || 1;
  // Oranı hesapla: hedef / mevcut
  const factor = targetPortions / current;
  const numRegex = /(\d+[\.,]?\d*)/g;

  // Sabit kalması gereken malzemeler (küçük harfe çevirerek kontrol et)
  const fixedIngredients = [
    'tuz', 'karabiber', 'kırmızıbiber', 'toz biber', 'pul biber',
    'karbonat', 'kabartma tozu', 'mayalama tozu',
    'vanilya', 'vanilin', 'vanilya özü',
    'limon suyu', 'sirke',
    'biberiye', 'kekik', 'nane', 'fesleğen',
    'tarçın', 'karanfil', 'yenibahar'
  ];

  const shouldKeepFixed = (ingredient) => {
    const lower = ingredient.toLowerCase();
    return fixedIngredients.some(fixed => lower.includes(fixed));
  };

  const transformed = { ...recipe };

  transformed.ingredients = recipe.ingredients.map(ing => {
    // Eğer sabit kalması gereken bir malzeme ise, sadece çok az artır (max %50)
    if (shouldKeepFixed(ing)) {
      // Sabit malzemeler için maksimum %50 artış (veya aynı kalır)
      const adjustedFactor = Math.min(factor, 1.5);
      return ing.replace(numRegex, (match) => {
        const val = parseFloat(match.replace(',', '.'));
        if (isNaN(val)) return match;
        // Eğer çok küçük bir değerse (çay kaşığı, tutam vb.) aynı kal
        if (val <= 2 && adjustedFactor > 1.2) {
          return match; // Aynı kal
        }
        const scaled = val * adjustedFactor;
        return scaled % 1 === 0 ? scaled.toString() : scaled.toFixed(1);
      });
    } else {
      // Normal malzemeler için orantılı ölçekleme
      return ing.replace(numRegex, (match) => {
        const val = parseFloat(match.replace(',', '.'));
        if (isNaN(val)) return match;
        const scaled = val * factor;
        return scaled % 1 === 0 ? scaled.toString() : scaled.toFixed(1);
      });
    }
  });

  transformed.title = `${recipe.title} (${targetPortions} porsiyon)`;
  transformed.portions = targetPortions;
  transformed.keywords = [...(recipe.keywords || []), 'porsiyon'];

  return transformed;
}


