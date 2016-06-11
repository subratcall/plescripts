**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

----
Ces scripts prennent en charge la création des LVs et de l'export sur le réseaux.

---

__Bibliothèques :__
* `targetclilib.sh` : contient toutes les fonctions permettant de manipuler targetcli
* `lvlib.sh` : fonction courante de manipulation des LVs.

---

__Création de nouveaux disques :__

create_lun_for_db.sh est utiliser par clone_master.sh, ce script va enchainer les
scripts de plus bas niveaux pour créer les disques et les exporter sur le réseau.

---

__Utilisation des scripts génériques :__

* create_initiator.sh : Création de l'initiator dans targetcli.

* Ajout de disques et/ou exports
	* add_and_export_lv.sh : Création des LV dans un VG puis export dans targetcli

	* export_lv.sh : Export de LVs existants dans targetcli.

	Les LUNs seront visibles pour les serveurs clients.

Puis aller sur le client pour mapper les LUNs (cf ../disk)

----

__Scripts divers :__
* create_lv.sh
	
	Création de 1 ou plusieurs LVs dans un VG.

	Ce scripts s'assure que les normes sont respectées.

* remove_lv.sh
	
	Suppression de 1 ou plusieurs LVs dans un VG.
	
	L'entête des LVs est effacé.

	Ne fonctionne que pour les LVs crées par create_lv.sh

* reset_all_for_db.sh
	
	Supprime le ou les initiators pour une base, le backstore et tous les LVS de
	la base seront remis à zéro.
	
* delete_intiator.sh

	Supprime un initiator le backstore reste intacte.	

* delete_backstore.sh

	Supprime un backstore, échouera si un initiator utilise un des disques
	du backstore.
		
	Les LVs restent intactes.

---

License
-------

Copyright (©) 2016 Philippe Leroux - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.