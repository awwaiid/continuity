
;; Heres the schema (all ONE table!). You'll want to insert a few rows by hand.

CREATE TABLE `InventoryItem` (
  `inventoryItem_id` int(11) NOT NULL auto_increment,
  `serial` varchar(50) default NULL,
  `name` varchar(100) default NULL,
  PRIMARY KEY  (`inventoryItem_id`)
);


CREATE TABLE InventoryItem (
  `inventoryItem_id` integer primary kqy,
  `serial` varchar(50) default NULL,
  `name` varchar(100) default NULL,
  PRIMARY KEY  (`inventoryItem_id`)
);
