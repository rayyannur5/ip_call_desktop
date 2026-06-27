/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.14-MariaDB, for debian-linux-gnu (aarch64)
--
-- Host: localhost    Database: ip-call
-- ------------------------------------------------------
-- Server version	10.11.14-MariaDB-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `adzan`
--

DROP TABLE IF EXISTS `adzan`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `adzan` (
  `key` varchar(255) NOT NULL,
  `value` time DEFAULT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `adzan`
--

LOCK TABLES `adzan` WRITE;
/*!40000 ALTER TABLE `adzan` DISABLE KEYS */;
INSERT INTO `adzan` VALUES
('ashar','14:48:00'),
('dhuhur','11:27:00'),
('isya','23:05:00'),
('maghrib','17:18:00'),
('subuh','04:12:00');
/*!40000 ALTER TABLE `adzan` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bed`
--

DROP TABLE IF EXISTS `bed`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bed` (
  `id` varchar(255) NOT NULL,
  `room_id` bigint(20) unsigned NOT NULL,
  `username` varchar(255) NOT NULL,
  `vol` int(11) NOT NULL DEFAULT 100,
  `mic` int(11) NOT NULL DEFAULT 100,
  `tw` int(11) NOT NULL DEFAULT 1,
  `mode` int(11) NOT NULL DEFAULT 0,
  `ip` varchar(255) DEFAULT NULL,
  `serial_number` varchar(255) DEFAULT NULL,
  `bypass` int(11) NOT NULL DEFAULT 0,
  `cable` tinyint(1) NOT NULL DEFAULT 0,
  `phone` varchar(6) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bed`
--

LOCK TABLES `bed` WRITE;
/*!40000 ALTER TABLE `bed` DISABLE KEYS */;
INSERT INTO `bed` VALUES
('010101',1,'Ruang Anggrek 1',50,100,1,0,'172.20.10.2',NULL,0,0,'010101'),
('010102',1,'Ruang Anggrek 2',100,100,1,0,NULL,NULL,0,0,'010102');
/*!40000 ALTER TABLE `bed` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `category_history`
--

DROP TABLE IF EXISTS `category_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `category_history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `category_history`
--

LOCK TABLES `category_history` WRITE;
/*!40000 ALTER TABLE `category_history` DISABLE KEYS */;
INSERT INTO `category_history` VALUES
(1,'PANGGILAN MASUK'),
(2,'PANGGILAN TIDAK TERJAWAB'),
(3,'PANGGILAN KELUAR');
/*!40000 ALTER TABLE `category_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `category_log`
--

DROP TABLE IF EXISTS `category_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `category_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `category_log`
--

LOCK TABLES `category_log` WRITE;
/*!40000 ALTER TABLE `category_log` DISABLE KEYS */;
INSERT INTO `category_log` VALUES
(1,'DARURAT'),
(2,'TELEPON'),
(3,'CODE BLUE'),
(4,'INFUS'),
(5,'PERAWAT');
/*!40000 ALTER TABLE `category_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `history`
--

DROP TABLE IF EXISTS `history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `bed_id` varchar(255) NOT NULL,
  `category_history_id` int(11) NOT NULL,
  `duration` varchar(255) DEFAULT NULL,
  `record` varchar(255) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `history`
--

LOCK TABLES `history` WRITE;
/*!40000 ALTER TABLE `history` DISABLE KEYS */;
INSERT INTO `history` VALUES
(1,'010101',1,'2 menit 25 detik','records/20260610-002150.wav','2026-06-09 17:24:16'),
(2,'010101',1,'52 detik','records/20260610-002906.wav','2026-06-09 17:26:10'),
(3,'010101',1,'32 detik','records/20260610-003231.wav','2026-06-09 17:33:05'),
(4,'010101',1,'8 detik','records/20260610-003809.wav','2026-06-09 17:38:19');
/*!40000 ALTER TABLE `history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `list_hour_audio`
--

DROP TABLE IF EXISTS `list_hour_audio`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `list_hour_audio` (
  `time` time NOT NULL,
  `vol` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `list_hour_audio`
--

LOCK TABLES `list_hour_audio` WRITE;
/*!40000 ALTER TABLE `list_hour_audio` DISABLE KEYS */;
/*!40000 ALTER TABLE `list_hour_audio` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `log`
--

DROP TABLE IF EXISTS `log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `category_log_id` int(10) unsigned NOT NULL,
  `value` text DEFAULT NULL,
  `device_id` varchar(255) DEFAULT NULL,
  `time` bigint(20) DEFAULT NULL,
  `nurse_presence` tinyint(1) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `log`
--

LOCK TABLES `log` WRITE;
/*!40000 ALTER TABLE `log` DISABLE KEYS */;
INSERT INTO `log` VALUES
(1,4,NULL,'010101',7,1,'2026-06-09 17:18:26'),
(2,4,NULL,'010101',7,1,'2026-06-09 17:18:45'),
(3,5,NULL,'010101',4,0,'2026-06-09 17:19:49'),
(4,2,NULL,'010101',3,0,'2026-06-09 17:24:19'),
(5,2,NULL,'010101',2,0,'2026-06-09 17:26:12'),
(6,5,NULL,'010101',9,0,'2026-06-09 17:30:06'),
(7,5,NULL,'010101',15,0,'2026-06-09 17:30:50'),
(8,5,NULL,'010101',10,0,'2026-06-09 17:32:12'),
(9,2,NULL,'010101',3,0,'2026-06-09 17:33:07'),
(10,5,NULL,'010101',5,0,'2026-06-09 17:38:02'),
(11,2,NULL,'010101',4,0,'2026-06-09 17:38:23');
/*!40000 ALTER TABLE `log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mastersound`
--

DROP TABLE IF EXISTS `mastersound`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `mastersound` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `source` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `mastersound_name_unique` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mastersound`
--

LOCK TABLES `mastersound` WRITE;
/*!40000 ALTER TABLE `mastersound` DISABLE KEYS */;
INSERT INTO `mastersound` VALUES
(1,'Ruang','static/ruang.mp3'),
(2,'Kamar','static/kamar.mp3'),
(3,'Toilet','static/toilet.mp3'),
(4,'Bed','static/Bed.mp3'),
(5,'Anggrek',NULL);
/*!40000 ALTER TABLE `mastersound` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `migrations` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) NOT NULL,
  `batch` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES
(1,'2019_12_14_000001_create_personal_access_tokens_table',1),
(2,'2026_01_26_000000_create_initial_tables',1),
(3,'2026_01_26_000001_create_oximonitor_tables',1),
(4,'2026_02_10_000000_add_cable_to_bed',1),
(5,'2026_02_12_091500_add_description_to_utils_table',1);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `oximonitor_log`
--

DROP TABLE IF EXISTS `oximonitor_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `oximonitor_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `volume` double(8,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `oximonitor_log`
--

LOCK TABLES `oximonitor_log` WRITE;
/*!40000 ALTER TABLE `oximonitor_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `oximonitor_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `oximonitor_status`
--

DROP TABLE IF EXISTS `oximonitor_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `oximonitor_status` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `flow_rate` double(8,2) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `oximonitor_status`
--

LOCK TABLES `oximonitor_status` WRITE;
/*!40000 ALTER TABLE `oximonitor_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `oximonitor_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `personal_access_tokens`
--

DROP TABLE IF EXISTS `personal_access_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `personal_access_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) NOT NULL,
  `tokenable_id` bigint(20) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `token` varchar(64) NOT NULL,
  `abilities` text DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `personal_access_tokens`
--

LOCK TABLES `personal_access_tokens` WRITE;
/*!40000 ALTER TABLE `personal_access_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `personal_access_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `playlist`
--

DROP TABLE IF EXISTS `playlist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlist` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `volume` int(11) NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `playlist`
--

LOCK TABLES `playlist` WRITE;
/*!40000 ALTER TABLE `playlist` DISABLE KEYS */;
INSERT INTO `playlist` VALUES
(1,'pl1',100,'12:00:00','23:55:00');
/*!40000 ALTER TABLE `playlist` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `playlist_item`
--

DROP TABLE IF EXISTS `playlist_item`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlist_item` (
  `id` int(11) NOT NULL,
  `ord` int(11) NOT NULL,
  `path` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`,`ord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `playlist_item`
--

LOCK TABLES `playlist_item` WRITE;
/*!40000 ALTER TABLE `playlist_item` DISABLE KEYS */;
INSERT INTO `playlist_item` VALUES
(1,1,'sholawat.mp3');
/*!40000 ALTER TABLE `playlist_item` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `room`
--

DROP TABLE IF EXISTS `room`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `room` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `running_text` varchar(255) DEFAULT NULL,
  `type_bed` varchar(255) DEFAULT NULL,
  `bed_separator` varchar(255) DEFAULT NULL,
  `serial_number` varchar(255) DEFAULT NULL,
  `bypass` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `room`
--

LOCK TABLES `room` WRITE;
/*!40000 ALTER TABLE `room` DISABLE KEYS */;
INSERT INTO `room` VALUES
(1,'Ruang','Anggrek',NULL,'numeric',NULL,NULL,0);
/*!40000 ALTER TABLE `room` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `running_text`
--

DROP TABLE IF EXISTS `running_text`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `running_text` (
  `topic` varchar(255) NOT NULL,
  `speed` int(11) DEFAULT NULL,
  `brightness` int(11) DEFAULT NULL,
  `serial_number` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`topic`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `running_text`
--

LOCK TABLES `running_text` WRITE;
/*!40000 ALTER TABLE `running_text` DISABLE KEYS */;
/*!40000 ALTER TABLE `running_text` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `toilet`
--

DROP TABLE IF EXISTS `toilet`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `toilet` (
  `id` varchar(255) NOT NULL,
  `room_id` bigint(20) unsigned NOT NULL,
  `username` varchar(255) NOT NULL,
  `serial_number` varchar(255) DEFAULT NULL,
  `bypass` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `toilet`
--

LOCK TABLES `toilet` WRITE;
/*!40000 ALTER TABLE `toilet` DISABLE KEYS */;
INSERT INTO `toilet` VALUES
('020101',1,'Toilet Anggrek',NULL,0);
/*!40000 ALTER TABLE `toilet` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES
(1,'teknisi','$2y$12$St5z.PXcxmczqqNdRu4pvei4ZLkyLnTbeX8MUO/9or5TuvJS3Mtsi','teknisi');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `utils`
--

DROP TABLE IF EXISTS `utils`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `utils` (
  `type` varchar(255) NOT NULL,
  `value` double NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `utils`
--

LOCK TABLES `utils` WRITE;
/*!40000 ALTER TABLE `utils` DISABLE KEYS */;
INSERT INTO `utils` VALUES
('adzan_active',1,'[PYTHON] Mengaktifkan adzan'),
('adzan_auto',0,'[PYTHON] Mengaktifkan jadwal adzan otomatis'),
('adzan_latitude',-7.2883547,'[PYTHON] Latitude adzan'),
('adzan_longitude',112.72549628466,'[PYTHON] Longitude adzan'),
('adzan_volume',10,'[PYTHON] Volume adzan'),
('interval_speaks',8000,'[APP] Interval waktu antar pengucapan pesan suara (Text-to-Speech)'),
('interval_update_status',120000,'[APP] Menentukan berapa lama status perangkat ditampilkan sebagai \"aktif\" sebelum kembali ke status offline jika tidak ada sinyal baru.'),
('one_room_one_device',0,'[SERVER] Program lama, jika ada 1 ruang 1 device'),
('time_autorefresh',0,'[APP] Waktu jeda sebelum halaman web memuat ulang (refresh) secara otomatis.'),
('timeout_call',60000,'[APP] Batas waktu (timeout) untuk panggilan telepon sebelum dianggap tidak terjawab.'),
('timeout_running_text',8500,'[PYTHON] Waktu jeda sebelum menampilkan teks berikutnya pada running text.'),
('timeout_time_activity',60000,'[DEVICE2W] Waktu setelah ada aktifitas tombol untuk memutar lagu playlist lagi'),
('toilet_priority',0,'[APP] Mengaktifkan prioritas panggilan toilet agar selalu berada di posisi paling atas');
/*!40000 ALTER TABLE `utils` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-06-13 11:49:04
