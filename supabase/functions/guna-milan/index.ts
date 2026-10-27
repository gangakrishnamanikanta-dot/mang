import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ─────────────────────────────────────────────────────────────────────────────
// CANONICAL VEDIC ASTROLOGY ASHTAKOOT DATA (Brihat Parashara Hora Shastra)
// ─────────────────────────────────────────────────────────────────────────────

// 12 Rashis:
// 1: Aries, 2: Taurus, 3: Gemini, 4: Cancer, 5: Leo, 6: Virgo,
// 7: Libra, 8: Scorpio, 9: Sagittarius, 10: Capricorn, 11: Aquarius, 12: Pisces

// Rashi Varna (1: Shudra, 2: Vaishya, 3: Kshatriya, 4: Brahmin)
const RASHI_VARNA: Record<number, number> = {
  1: 3, 2: 2, 3: 1, 4: 4, 5: 3, 6: 2, 7: 1, 8: 4, 9: 3, 10: 2, 11: 1, 12: 4,
};

// 27 Nakshatras:
// Ganas: 0 = Deva, 1 = Manushya, 2 = Rakshasa
const NAKSHATRA_GANA: Record<number, number> = {
  1: 0, 2: 1, 3: 2, 4: 1, 5: 0, 6: 1, 7: 0, 8: 0, 9: 2,
  10: 2, 11: 1, 12: 1, 13: 0, 14: 2, 15: 0, 16: 2, 17: 0, 18: 2,
  19: 2, 20: 1, 21: 1, 22: 0, 23: 2, 24: 2, 25: 1, 26: 1, 27: 0,
};

// Nadis: 0 = Adi (Vata), 1 = Madhya (Pitta), 2 = Antya (Kapha) - Serpentine wave
const NAKSHATRA_NADI: Record<number, number> = {
  1: 0, 2: 1, 3: 2, 4: 2, 5: 1, 6: 0, 7: 0, 8: 1, 9: 2,
  10: 0, 11: 1, 12: 2, 13: 2, 14: 1, 15: 0, 16: 0, 17: 1, 18: 2,
  19: 0, 20: 1, 21: 2, 22: 2, 23: 1, 24: 0, 25: 0, 26: 1, 27: 2,
};

// Yoni Animals: 1=Horse, 2=Elephant, 3=Sheep, 4=Serpent, 5=Dog, 6=Cat, 7=Rat,
// 8=Cow, 9=Buffalo, 10=Tiger, 11=Deer, 12=Monkey, 13=Mongoose, 14=Lion
const NAKSHATRA_YONI: Record<number, number> = {
  1: 1,  2: 2,  3: 3,  4: 4,  5: 4,  6: 5,  7: 6,  8: 3,  9: 6,
  10: 7, 11: 7, 12: 8, 13: 9, 14: 10, 15: 9, 16: 10, 17: 11, 18: 11,
  19: 5, 20: 12, 21: 13, 22: 12, 23: 14, 24: 1, 25: 14, 26: 8, 27: 2,
};

// Sworn Enemies Yoni Pairs (Score = 0)
const YONI_SWORN_ENEMIES: [number, number][] = [
  [1, 9],  // Horse vs Buffalo
  [2, 14], // Elephant vs Lion
  [3, 12], // Sheep vs Monkey
  [4, 13], // Serpent vs Mongoose
  [5, 11], // Dog vs Deer
  [6, 7],  // Cat vs Rat
  [8, 10], // Cow vs Tiger
];

// Rashi Ruling Lords (1:Sun, 2:Moon, 3:Mars, 4:Mercury, 5:Jupiter, 6:Venus, 7:Saturn)
const RASHI_LORD_NORM: Record<number, number> = {
  1: 3, 2: 6, 3: 4, 4: 2, 5: 1, 6: 4, 7: 6, 8: 3, 9: 5, 10: 7, 11: 7, 12: 5,
};

export interface MatchRequest {
  boy_rashi_id: number;
  boy_nakshatra_id: number;
  boy_pada?: number;
  boy_is_manglik?: boolean;
  girl_rashi_id: number;
  girl_nakshatra_id: number;
  girl_pada?: number;
  girl_is_manglik?: boolean;
}

export function calculateCanonicalAshtakoot(req: MatchRequest) {
  const {
    boy_rashi_id, boy_nakshatra_id, boy_pada = 1,
    girl_rashi_id, girl_nakshatra_id, girl_pada = 1,
    boy_is_manglik = false, girl_is_manglik = false,
  } = req;

  if (
    !boy_rashi_id || !girl_rashi_id || !boy_nakshatra_id || !girl_nakshatra_id ||
    boy_rashi_id < 1 || boy_rashi_id > 12 || girl_rashi_id < 1 || girl_rashi_id > 12 ||
    boy_nakshatra_id < 1 || boy_nakshatra_id > 27 || girl_nakshatra_id < 1 || girl_nakshatra_id > 27
  ) {
    return {
      total_guna_score: null,
      max_score: 36,
      verdict: "Incomplete Astrology Data",
      is_auspicious: false,
      breakdown: null,
    };
  }

  // 1. Varna Koota (1 pt max)
  const boyVarna = RASHI_VARNA[boy_rashi_id] ?? 1;
  const girlVarna = RASHI_VARNA[girl_rashi_id] ?? 1;
  const varnaScore = boyVarna >= girlVarna ? 1 : 0;

  // 2. Vashya Koota (2 pts max)
  let vashyaScore = 1;
  if (boy_rashi_id === girl_rashi_id) {
    vashyaScore = 2;
  } else if (
    ([1, 2].includes(boy_rashi_id) && [1, 2].includes(girl_rashi_id)) ||
    ([3, 6, 7, 11].includes(boy_rashi_id) && [3, 6, 7, 11].includes(girl_rashi_id)) ||
    ([4, 12].includes(boy_rashi_id) && [4, 12].includes(girl_rashi_id))
  ) {
    vashyaScore = 2;
  } else if (
    ([1, 2].includes(boy_rashi_id) && [3, 6, 7, 11].includes(girl_rashi_id)) ||
    ([3, 6, 7, 11].includes(boy_rashi_id) && [1, 2].includes(girl_rashi_id)) ||
    ([3, 6, 7, 11].includes(boy_rashi_id) && [4, 12].includes(girl_rashi_id)) ||
    ([4, 12].includes(boy_rashi_id) && [3, 6, 7, 11].includes(girl_rashi_id))
  ) {
    vashyaScore = 1;
  } else if (
    ([1, 2].includes(boy_rashi_id) && [4, 12].includes(girl_rashi_id)) ||
    ([4, 12].includes(boy_rashi_id) && [1, 2].includes(girl_rashi_id))
  ) {
    vashyaScore = 0.5;
  } else if (boy_rashi_id === 5 || girl_rashi_id === 5) {
    vashyaScore = (boy_rashi_id === 7 || girl_rashi_id === 7) ? 1 : 0;
  } else if (boy_rashi_id === 8 || girl_rashi_id === 8) {
    vashyaScore = (boy_rashi_id === 4 || girl_rashi_id === 4) ? 1 : 0;
  }

  // 3. Tara Koota (3 pts max) - Classical Brihat Parashara 1-Indexed Inclusive
  const taraGtoB = (((boy_nakshatra_id - girl_nakshatra_id + 27) % 27) % 9) + 1;
  const taraBtoG = (((girl_nakshatra_id - boy_nakshatra_id + 27) % 27) % 9) + 1;

  let taraScore = 0;
  const inauspiciousTaras = [3, 5, 7];
  const gToBOk = !inauspiciousTaras.includes(taraGtoB);
  const bToGOk = !inauspiciousTaras.includes(taraBtoG);
  if (gToBOk && bToGOk) {
    taraScore = 3;
  } else if (gToBOk || bToGOk) {
    taraScore = 1.5;
  } else {
    taraScore = 0;
  }

  // 4. Yoni Koota (4 pts max)
  const boyYoni = NAKSHATRA_YONI[boy_nakshatra_id] ?? 1;
  const girlYoni = NAKSHATRA_YONI[girl_nakshatra_id] ?? 1;
  let yoniScore = 2;

  if (boyYoni === girlYoni) {
    yoniScore = 4;
  } else {
    const isEnemy = YONI_SWORN_ENEMIES.some(
      ([a, b]) => (boyYoni === a && girlYoni === b) || (boyYoni === b && girlYoni === a)
    );
    yoniScore = isEnemy ? 0 : 2;
  }

  // 5. Graha Maitri (5 pts max)
  const boyLord = RASHI_LORD_NORM[boy_rashi_id] ?? 1;
  const girlLord = RASHI_LORD_NORM[girl_rashi_id] ?? 1;
  let maitriScore = 3;

  if (boyLord === girlLord) {
    maitriScore = 5;
  } else if ([1, 2, 3, 5].includes(boyLord) && [1, 2, 3, 5].includes(girlLord)) {
    maitriScore = 5;
  } else if ([4, 6, 7].includes(boyLord) && [4, 6, 7].includes(girlLord)) {
    maitriScore = 5;
  } else if ((boyLord === 4 && girlLord === 1) || (boyLord === 1 && girlLord === 4)) {
    maitriScore = 4;
  } else if (
    ([1, 2].includes(boyLord) && [6, 7].includes(girlLord)) ||
    ([6, 7].includes(boyLord) && [1, 2].includes(girlLord))
  ) {
    maitriScore = 0.5;
  } else if ((boyLord === 3 && girlLord === 4) || (boyLord === 4 && girlLord === 3)) {
    maitriScore = 0.5;
  }

  // 6. Gana Koota (6 pts max)
  const boyGana = NAKSHATRA_GANA[boy_nakshatra_id] ?? 0;
  const girlGana = NAKSHATRA_GANA[girl_nakshatra_id] ?? 0;
  let ganaScore = 0;

  if (boyGana === girlGana) {
    ganaScore = 6;
  } else if (boyGana === 0 && girlGana === 1) {
    ganaScore = 6;
  } else if (boyGana === 1 && girlGana === 0) {
    ganaScore = 5;
  } else if (boyGana === 0 && girlGana === 2) {
    ganaScore = 1;
  } else {
    ganaScore = 0;
  }

  // 7. Bhakoot Koota (7 pts max)
  const rashiDiff = Math.abs(boy_rashi_id - girl_rashi_id);
  let bhakootScore = 0;
  let bhakootParihara = false;

  if ([0, 6, 2, 10, 3, 9].includes(rashiDiff)) {
    bhakootScore = 7;
  } else {
    // Bhakoot Parihara
    if (boyLord === girlLord || maitriScore >= 4) {
      bhakootScore = 7;
      bhakootParihara = true;
    } else {
      bhakootScore = 0;
    }
  }

  // 8. Nadi Koota (8 pts max)
  const boyNadi = NAKSHATRA_NADI[boy_nakshatra_id] ?? 0;
  const girlNadi = NAKSHATRA_NADI[girl_nakshatra_id] ?? 0;
  let nadiScore = 8;
  let nadiDosha = false;
  let nadiParihara = false;

  if (boyNadi !== girlNadi) {
    nadiScore = 8;
  } else {
    nadiDosha = true;
    if (boy_nakshatra_id !== girl_nakshatra_id) {
      if (boy_rashi_id !== girl_rashi_id && maitriScore >= 4) {
        nadiScore = 8;
        nadiParihara = true;
      } else {
        nadiScore = 0;
      }
    } else if (boy_pada !== girl_pada) {
      nadiScore = 8;
      nadiParihara = true;
    } else {
      nadiScore = 0;
    }
  }

  // Kuja Dosha Compatibility
  let kujaStatus = "No Dosha";
  if (boy_is_manglik && girl_is_manglik) {
    kujaStatus = "Kuja Dosha Cancelled (Both Manglik - Auspicious)";
  } else if (boy_is_manglik || girl_is_manglik) {
    kujaStatus = "Single Kuja Dosha (Consult Astrologer)";
  }

  const rawTotal =
    varnaScore + vashyaScore + taraScore + yoniScore + maitriScore + ganaScore + bhakootScore + nadiScore;
  const totalScore = Math.min(36, Math.max(0, Math.round(rawTotal * 10) / 10));

  let verdict = "Madhyama Milan (Good Match)";
  if (totalScore >= 28) {
    verdict = "Uttama Milan (Highly Auspicious Match)";
  } else if (totalScore < 18) {
    verdict = "Alpa Milan (Low Astrological Compatibility)";
  }

  return {
    total_guna_score: totalScore,
    max_score: 36,
    verdict,
    is_auspicious: totalScore >= 18,
    kuja_dosha_status: kujaStatus,
    nadi_dosha: nadiDosha,
    nadi_dosha_cancelled: nadiParihara,
    bhakoot_dosha_cancelled: bhakootParihara,
    breakdown: {
      varna: { name: "Varna (Spiritual)", score: varnaScore, max: 1 },
      vashya: { name: "Vashya (Attraction)", score: vashyaScore, max: 2 },
      tara: { name: "Tara (Health & Destiny)", score: taraScore, max: 3 },
      yoni: { name: "Yoni (Physical Harmony)", score: yoniScore, max: 4 },
      graha_maitri: { name: "Graha Maitri (Mental Harmony)", score: maitriScore, max: 5 },
      gana: { name: "Gana (Temperament)", score: ganaScore, max: 6 },
      bhakoot: { name: "Bhakoot (Emotional Bond)", score: bhakootScore, max: 7 },
      nadi: { name: "Nadi (Genetic Compatibility)", score: nadiScore, max: 8 },
    },
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const body = await req.json();
    const result = calculateCanonicalAshtakoot(body);

    return new Response(JSON.stringify(result), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 400,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
