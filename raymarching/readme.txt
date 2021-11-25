Megvalósított részfeladatok:
-Befoglaló: a térfogat befoglaló dobozával számoljon metszéspontot, és csak a be- és kilépési pont között vegyen mintákat a 3D textúrából.
-Szintfelület: keresse meg a sugár metszéspontját a sűrűségmező valamely szintfelületével. Használjon trilineáris interpolációt.
	Árnyalja a felületet a Phong (vagy Phong-Blinn) modellnek megfelelően.
-Matcap: árnyalja a szintfelületet egy material capture textúra segtségével. _Ne_ tükrözött környezetként használja a textúrát
	(evnironment mapping), hanem a kameratérbeli normálvektorral címezze.
-Hagymahéj: rajzoljon több szintfelületet egyszerre. A szintfelületek legyenek részben átlátszóak, és az átlátszóság függjön a
	nézeti irány és a normálvektor által bezárt szögtől (a sziluettek mentén legyen kevésbé átlátszó).
-Önárnyék: a szintfelület vessen árnyékot magára.
-Térfogati árnyalás: A sűrűségmező adja meg a közeg csillapítási tényezőjét és a forrástagot egyaránt. Értékelje ki a térfogati árnyalási egyenletet numerikusan.

A programban nyomógombok segítségével lehet váltani a megjelenítési üzemmódok között, ezt a program is mutatja működés, közben, hogy melyik üzemmódot milyen
nyomógombbal lehet bekapcsolni. A szintfelületi határt is lehet nyomógombokkal változtatni. Ezek a következők:
m:matcap üzemmód
b:szintfelületet megjelenítő üzemmód önárnyékkal, és phong árnyalással
g:térfogati árnyalásos csillapításos/forrástagos közeg
l:hagymahéj-szerű réteges megjelenítés
n:normálvektorokat megjelenítő tesztüzemmód
o:szintfelület határérték csökkentése
p:szintfelület határérték növelése