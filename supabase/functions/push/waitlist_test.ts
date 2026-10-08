// deno test supabase/functions/push/waitlist_test.ts
import { guestCategory, seatFreed, waitlistToNotify } from "./waitlist.ts";

function assertEquals(actual: unknown, expected: unknown, msg = "") {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${msg} atteso ${e}, ottenuto ${a}`);
}

const noLimits = { max_couples: null, max_women: null, max_men: null };
const list = [
  { user_id: "k2", profile_type: "Coppia D/D" },
  { user_id: "d1", profile_type: "Donna Singola" },
  { user_id: "u1", profile_type: "Uomo Singolo" },
  { user_id: "x1", profile_type: null },
];

Deno.test("categorie come la 0022", () => {
  assertEquals(guestCategory("Coppia U/U"), "coppia");
  assertEquals(guestCategory("Donna Singola"), "donna");
  assertEquals(guestCategory("Uomo Singolo"), "uomo");
  assertEquals(guestCategory(null), null);
  assertEquals(guestCategory("Altro"), null);
});

Deno.test("posto liberato solo da approvato a non approvato", () => {
  assertEquals(seatFreed("approved", "rejected"), true);
  assertEquals(seatFreed("pending", "rejected"), false);
  assertEquals(seatFreed("waitlisted", "approved"), false);
  assertEquals(seatFreed("approved", "approved"), false);
});

Deno.test("senza limiti per categoria: tutti quelli in lista", () => {
  assertEquals(waitlistToNotify("coppia", noLimits, list), ["k2", "d1", "u1", "x1"]);
});

Deno.test("con limiti: la stessa categoria e chi ha solo il totale", () => {
  const limits = { max_couples: 2, max_women: 3, max_men: null };
  assertEquals(waitlistToNotify("coppia", limits, list), ["k2", "u1", "x1"]);
  assertEquals(waitlistToNotify("donna", limits, list), ["d1", "u1", "x1"]);
});

Deno.test("ospite liberato senza tipologia: solo chi ha il totale", () => {
  const limits = { max_couples: 2, max_women: 3, max_men: 1 };
  assertEquals(waitlistToNotify(null, limits, list), ["x1"]);
});

Deno.test("lista vuota, nessun doppione", () => {
  assertEquals(waitlistToNotify("coppia", noLimits, []), []);
  assertEquals(
    waitlistToNotify("coppia", noLimits, [list[0], list[0]]),
    ["k2"],
  );
});
