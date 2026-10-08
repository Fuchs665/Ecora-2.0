// ============================================================================
// Blocco L.3: chi avvisare quando si libera un posto (lista d'attesa, 0023).
// Puro: nessun accesso a database o rete, provato da waitlist_test.ts.
// ============================================================================

export type Category = "coppia" | "donna" | "uomo";

/** Stessi valori di guest_category() della 0022. */
export function guestCategory(profileType: unknown): Category | null {
  switch (profileType) {
    case "Coppia U/D":
    case "Coppia D/D":
    case "Coppia U/U":
      return "coppia";
    case "Donna Singola":
      return "donna";
    case "Uomo Singolo":
      return "uomo";
    default:
      return null;
  }
}

export type EventLimits = {
  max_couples: number | null;
  max_women: number | null;
  max_men: number | null;
};

export type WaitlistedGuest = { user_id: string; profile_type: unknown };

function limitFor(event: EventLimits, category: Category | null) {
  switch (category) {
    case "coppia":
      return event.max_couples;
    case "donna":
      return event.max_women;
    case "uomo":
      return event.max_men;
    default:
      return null;
  }
}

/** Vero quando una richiesta approvata smette di esserlo: si libera un posto. */
export function seatFreed(oldStatus: string, newStatus: string): boolean {
  return oldStatus === "approved" && newStatus !== "approved";
}

/**
 * Chi in lista può entrare nel posto liberato da un ospite di categoria
 * [freed]: chi è della stessa categoria, e chi ha la sola limitazione del
 * totale (la sua categoria non ha un limite). Gli altri restano bloccati
 * dal limite della loro categoria e non vengono avvisati. Senza doppioni.
 */
export function waitlistToNotify(
  freed: Category | null,
  event: EventLimits,
  waitlisted: WaitlistedGuest[],
): string[] {
  const out = new Set<string>();
  for (const guest of waitlisted) {
    const category = guestCategory(guest.profile_type);
    const sameCategory = category !== null && category === freed;
    if (sameCategory || limitFor(event, category) === null) {
      out.add(guest.user_id);
    }
  }
  return [...out];
}
