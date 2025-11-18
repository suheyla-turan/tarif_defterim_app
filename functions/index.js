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

// AI ile alışveriş listesi malzemelerini parse et
exports.parseShoppingIngredients = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Kullanıcı girişi gerekli'
    );
  }

  const { ingredients } = data;

  if (!ingredients || !Array.isArray(ingredients)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Malzeme listesi gerekli'
    );
  }

  if (!OPENAI_API_KEY) {
    // Fallback: basit parsing
    return { items: ingredients.map(ing => ({ name: ing.trim().toLowerCase() })) };
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
            content: 'Sen bir alışveriş listesi uzmanısın. Verilen malzeme listesini parse et ve her malzeme için isim, miktar ve birim bilgilerini çıkar. Sadece JSON formatında döndür.'
          },
          {
            role: 'user',
            content: `Şu malzemeleri parse et:\n${ingredients.join('\n')}\n\nJSON formatında şu yapıda döndür: {"items": [{"name": "...", "quantity": ..., "unit": "..."}, ...]}`
          }
        ],
        temperature: 0.3,
        max_tokens: 1500
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.statusText}`);
    }

    const result = await response.json();
    const content = result.choices[0].message.content;
    
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
      return { items: ingredients.map(ing => ({ name: ing.trim().toLowerCase() })) };
    }

    return aiResult;
  } catch (error) {
    console.error('OpenAI parse error:', error);
    return { items: ingredients.map(ing => ({ name: ing.trim().toLowerCase() })) };
  }
});

// AI ile alışveriş listesindeki tüm tariflerin malzemelerini birleştir
exports.mergeShoppingList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Kullanıcı girişi gerekli'
    );
  }

  const { recipes } = data;

  if (!recipes || !Array.isArray(recipes) || recipes.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Tarif listesi gerekli'
    );
  }

  // Tüm tariflerin malzemelerini topla
  const allIngredients = [];
  recipes.forEach((recipe, index) => {
    if (recipe.items && Array.isArray(recipe.items)) {
      recipe.items.forEach(item => {
        allIngredients.push({
          recipeIndex: index,
          recipeTitle: recipe.recipeTitle || `Tarif ${index + 1}`,
          name: item.name || '',
          quantity: item.quantity || null,
          unit: item.unit || null
        });
      });
    }
  });

  if (allIngredients.length === 0) {
    return { items: [] };
  }

  if (!OPENAI_API_KEY) {
    // Fallback: basit birleştirme
    return mergeShoppingListFallback(allIngredients);
  }

  try {
    // AI'ya gönderilecek format
    const ingredientsText = allIngredients.map((ing, idx) => {
      let text = `${idx + 1}. ${ing.name}`;
      if (ing.quantity !== null) {
        text += ` - ${ing.quantity}`;
      }
      if (ing.unit) {
        text += ` ${ing.unit}`;
      }
      text += ` (${ing.recipeTitle})`;
      return text;
    }).join('\n');

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
            content: 'Sen bir alışveriş listesi uzmanısın. Verilen malzeme listesindeki aynı veya benzer malzemeleri birleştir. Aynı birimdeki miktarları topla. Farklı birimlerdeki malzemeleri (örneğin gr ve kg) uygun şekilde dönüştür ve birleştir. Sadece JSON formatında döndür.'
          },
          {
            role: 'user',
            content: `Şu malzemeleri birleştir ve ortak olanların miktarlarını topla:\n\n${ingredientsText}\n\nJSON formatında şu yapıda döndür: {"items": [{"name": "...", "quantity": ..., "unit": "..."}, ...]}\n\nÖnemli: Aynı malzemeleri birleştir, miktarları topla. Farklı birimleri uygun şekilde dönüştür (örneğin 500 gr + 0.5 kg = 1 kg).`
          }
        ],
        temperature: 0.3,
        max_tokens: 2000
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.statusText}`);
    }

    const result = await response.json();
    const content = result.choices[0].message.content;
    
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
      return mergeShoppingListFallback(allIngredients);
    }

    // AI sonucunu normalize et
    if (aiResult.items && Array.isArray(aiResult.items)) {
      return {
        items: aiResult.items.map(item => ({
          name: (item.name || '').toLowerCase().trim(),
          quantity: item.quantity ? parseFloat(item.quantity) : null,
          unit: item.unit || null
        }))
      };
    }

    return mergeShoppingListFallback(allIngredients);
  } catch (error) {
    console.error('OpenAI merge error:', error);
    return mergeShoppingListFallback(allIngredients);
  }
});

// Fallback: basit birleştirme
function mergeShoppingListFallback(allIngredients) {
  const merged = {};
  
  allIngredients.forEach(ing => {
    const key = ing.name.toLowerCase().trim();
    if (!merged[key]) {
      merged[key] = {
        name: key,
        quantity: ing.quantity,
        unit: ing.unit
      };
    } else {
      // Aynı birimdeyse topla
      if (merged[key].unit === ing.unit && merged[key].quantity && ing.quantity) {
        merged[key].quantity = merged[key].quantity + ing.quantity;
      } else if (merged[key].quantity && ing.quantity) {
        // Farklı birimler - basit toplama (dönüşüm yapmadan)
        merged[key].quantity = merged[key].quantity + ing.quantity;
        merged[key].unit = merged[key].unit || ing.unit;
      }
    }
  });

  return {
    items: Object.values(merged).map(item => ({
      name: item.name,
      quantity: item.quantity,
      unit: item.unit
    }))
  };
}

