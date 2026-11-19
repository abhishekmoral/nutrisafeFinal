// Barcode helpers. Product databases store the same pack under slightly different numbers
// (UPC-A "012345678905" vs EAN-13 "0012345678905"), so every lookup uses a normalised GTIN-13.

/** GS1 check digit of the digits before it (works for GTIN-8/12/13/14). */
export function checkDigit(body: string): number {
  let sum = 0;
  for (let i = 0; i < body.length; i++) {
    const digit = body.charCodeAt(body.length - 1 - i) - 48;
    sum += digit * (i % 2 === 0 ? 3 : 1);
  }
  return (10 - (sum % 10)) % 10;
}

export function hasValidCheckDigit(code: string): boolean {
  if (!/^\d{8,14}$/.test(code)) return false;
  return checkDigit(code.slice(0, -1)) === Number(code[code.length - 1]);
}

/** UPC-E (8 digits, number system 0 or 1) to the UPC-A it stands for. */
export function upcEToUpcA(upce: string): string | null {
  if (!/^[01]\d{7}$/.test(upce)) return null;
  const ns = upce[0];
  const d = upce.slice(1, 7);
  const check = upce[7];
  const last = d[5];
  let body: string;
  if (last === "0" || last === "1" || last === "2") body = `${d[0]}${d[1]}${last}0000${d[2]}${d[3]}${d[4]}`;
  else if (last === "3") body = `${d[0]}${d[1]}${d[2]}00000${d[3]}${d[4]}`;
  else if (last === "4") body = `${d[0]}${d[1]}${d[2]}${d[3]}00000${d[4]}`;
  else body = `${d[0]}${d[1]}${d[2]}${d[3]}${d[4]}0000${last}`;
  return `${ns}${body}${check}`;
}

export interface NormalisedBarcode {
  gtin13: string; // cache key; EAN-8 codes stay 8 digits
  variants: string[]; // every spelling a database may use, most likely first
}

/**
 * Cleans a scanned code. Returns null when it is not a valid retail barcode
 * (wrong length or wrong check digit, which usually means a bad scan).
 */
export function normaliseBarcode(raw: string, format?: string): NormalisedBarcode | null {
  let code = (raw ?? "").replace(/\D/g, "");
  if (format === "upce" || format === "upc_e") {
    const upca = upcEToUpcA(code);
    if (!upca) return null;
    code = upca;
  }
  if (!hasValidCheckDigit(code)) return null;
  if (code.length === 8) return { gtin13: code, variants: [code] };

  // 12, 13 or 14 digits: strip leading zeros down to 13 (GTIN-14 with a packaging indicator stays 14).
  let gtin = code;
  while (gtin.length > 13 && gtin.startsWith("0")) gtin = gtin.slice(1);
  if (gtin.length === 12) gtin = `0${gtin}`;
  const variants = [gtin];
  if (gtin.length === 13 && gtin.startsWith("0")) variants.push(gtin.slice(1)); // UPC-A spelling
  if (code !== gtin && !variants.includes(code)) variants.push(code);
  return { gtin13: gtin, variants };
}

/** Same product number? (ignores leading zeros) */
export function sameGtin(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false;
  const strip = (s: string) => s.replace(/\D/g, "").replace(/^0+/, "");
  return strip(a) !== "" && strip(a) === strip(b);
}

/** 890 is the GS1 India prefix: the brand owner registered the barcode in India. */
export function isIndianBarcode(gtin13: string): boolean {
  return gtin13.length === 13 && gtin13.startsWith("890");
}
