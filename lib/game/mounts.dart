// Mounts. Ride one and every fight opens with a Charge: you gallop across the field and run the
// foe down before your first blow. Ponies and warhorses come from the merchant; the Nightmare is
// the Gloomfen's gift, and a tamed wyvern is won in the Cinderreach.

class Mount {
  const Mount(this.id, this.name, this.desc, this.charge, {this.price = 0, this.mend = 0, this.burn = false, this.flying = false});
  final String id, name, desc;

  /// The Charge's damage as a share of an attack.
  final double charge;

  /// Gold at the merchant; 0 for a mount only won in battle.
  final int price;

  /// Share of your health the Charge mends (the unicorn).
  final double mend;

  /// The Charge leaves the foe burning (the Nightmare): 3 fire per hero level.
  final bool burn;

  /// Swoops from the sky instead of galloping (the wyvern).
  final bool flying;

  bool get dropOnly => price == 0;
}

const mounts = <Mount>[
  Mount('pony', 'Sturdy pony', 'Small, stubborn and surprisingly brave. Charge: 30% of an attack', .3, price: 180),
  Mount('warhorse', 'Warhorse', 'A barded destrier trained for the lists. Charge: 50% of an attack', .5, price: 700),
  Mount('unicorn', 'Unicorn', 'Tamed in the Thornwild, very politely. Charge: 55% of an attack, and its horn mends 8% of your health', .55, mend: .08),
  Mount('nightmare', 'Nightmare', 'A ghostly black horse from the Bone Colossus\'s ribcage. It snorts embers. Charge: 60% of an attack, and the foe burns', .6, burn: true),
  Mount('wyvern', 'Tamed wyvern', 'It swoops rather than gallops, and it bites. Charge: 65% of an attack', .65, flying: true),
  Mount('griffin', 'Griffin', 'Raised from a chick won in the Skyreach Aeries. It dives out of the sun with its talons out. Charge: 70% of an attack', .7, flying: true),
];

Mount? mountById(String? id) => mounts.where((m) => m.id == id).firstOrNull;

/// Mounts won in battle: (foe look, mount, chance).
const mountDrops = <String, (String, double)>{
  'unicorn': ('unicorn', .04),
  'wyvern': ('wyvern', .06),
  'griffin': ('griffin', .04),
};
