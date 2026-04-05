/// All translatable strings keyed by locale code → translation key → value.
class AppTranslations {
  const AppTranslations._();

  static const Map<String, Map<String, String>> _translations = {
    'en': _en,
    'fil': _fil,
  };

  static String get(String locale, String key) {
    return _translations[locale]?[key] ?? _translations['en']?[key] ?? key;
  }

  // ─── English ───
  static const Map<String, String> _en = {
    // Bottom nav
    'nav_home': 'Home',
    'nav_alerts': 'Alerts',
    'nav_booking': 'Booking',
    'nav_tps': 'TPS',
    'nav_farmers': 'Farmers',
    'nav_account': 'Account',

    // Account – sections
    'section_account': 'ACCOUNT',
    'section_services': 'SERVICES',
    'section_support': 'SUPPORT',

    // Account – menu items
    'edit_profile': 'Edit Profile',
    'change_password': 'Change Password',
    'phone_number': 'Phone Number',
    'verified': 'Verified',
    'not_verified': 'Not verified',
    'tickets': 'Tickets',
    'maintenance': 'Maintenance',
    'geo_fences': 'Geo Fences',
    'feedback': 'Feedback',
    'reports': 'Reports',
    'language': 'Language',
    'help_center': 'Help Center',
    'about_tanod': 'About TanodTractor',
    'terms_privacy': 'Terms & Privacy',
    'sign_out': 'Sign Out',
    'sign_out_message': 'Are you sure you want to sign out of your account?',
    'app_version': 'TanodTractor v1.0.0',

    // Account deletion
    'delete_account': 'Delete Account',
    'delete_account_title': 'Account Deletion',
    'delete_account_warning_title': 'This action is irreversible',
    'delete_account_warning_body':
        'Deleting your account will permanently remove all your data, including your profile, bookings, tractors, and activity history. This cannot be undone.',
    'delete_account_grace_title': 'What happens next?',
    'delete_account_grace_body':
        'Your account will be scheduled for deletion after a 7-day grace period. During this time you can still sign in and cancel the request.',
    'delete_account_notify_body':
        'A confirmation email and SMS will be sent to notify you of the scheduled deletion.',
    'delete_account_password_label': 'Enter your password to confirm',
    'delete_account_password_hint': 'Current password',
    'delete_account_confirm': 'Delete My Account',
    'delete_account_cancel': 'Cancel Deletion',
    'delete_account_success':
        'Account deletion requested. You have 7 days to cancel.',
    'delete_account_cancel_success': 'Account deletion has been cancelled.',
    'delete_account_pending_title': 'Deletion Scheduled',
    'delete_account_pending_body':
        'Your account is scheduled for permanent deletion on:',
    'delete_account_pending_cancel_info':
        'You can cancel this request before the date above to keep your account.',
    'delete_account_days_remaining': 'days remaining',
    'delete_account_confirm_dialog_title': 'Confirm Deletion',
    'delete_account_confirm_dialog_message':
        'This will schedule your account for permanent deletion in 7 days. Are you sure?',

    // Language picker
    'select_language': 'Select Language',
    'english': 'English',
    'tagalog': 'Filipino (Tagalog)',

    // Common
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'save': 'Save',
    'delete': 'Delete',
    'search': 'Search',
    'loading': 'Loading...',
    'no_data': 'No data available',
    'error': 'Something went wrong',
    'retry': 'Retry',
    'success': 'Success',

    // Help Center
    'help_center_subtitle': 'Get help and contact your support team',
    'your_fca': 'Your FCA Coordinator',
    'assigned_tps': 'Assigned TPS Technicians',
    'system_support': 'System Support',
    'fca_label': 'FCA',
    'tps_label': 'TPS',
    'admin_label': 'SUPPORT',
    'quick_help': 'Quick Help',

    // TPS Distribution
    'distribute_tractor': 'Distribute Tractor',
    'create_ticket': 'Create Ticket',
    'distribute_tractor_subtitle': 'Assign a tractor to an FCA',
    'select_tractor': 'Select Tractor',
    'select_tractor_hint': 'Choose a tractor to distribute',
    'tractor_already_distributed': 'Already distributed',
    'select_fca': 'Select FCA',
    'select_fca_hint': 'Choose an FCA recipient',
    'distribution_area': 'Area / Location',
    'distribution_area_hint': 'e.g. Brgy. San Jose, Tarlac',
    'distribution_date': 'Distribution Date',
    'distribution_notes': 'Notes (optional)',
    'distribution_notes_hint': 'Additional remarks...',
    'distribute_submit': 'Distribute Tractor',
    'distribute_success': 'Tractor distributed successfully!',
    'distribute_error': 'Failed to distribute tractor.',
    'no_tractors_available': 'No tractors available for distribution.',
    'no_fca_users_available': 'No FCA users available.',

    'help_tickets_title': 'Submit a Ticket',
    'help_tickets_desc':
        'Report issues or request assistance through the ticket system.',
    'help_call_title': 'Call Support',
    'help_call_desc':
        'Reach our support team directly for urgent concerns.',
    'help_hours_title': 'Operating Hours',
    'help_hours_desc': 'Monday – Friday, 8:00 AM – 5:00 PM (PHT)',

    // FAQ
    'faq_title': 'Frequently Asked Questions',
    'faq_q1': 'How do I book a tractor?',
    'faq_a1':
        'Go to the Booking tab, select an available tractor, choose your preferred date and time slot, fill in the purpose and area, then submit your booking request. Your FCA will review and approve it.',
    'faq_q2': 'How can I track my tractor in real-time?',
    'faq_a2':
        'Open the Home tab to see all your assigned tractors on the map. Tap on any tractor to view its live location, speed, and current status.',
    'faq_q3': 'What should I do if the tractor breaks down?',
    'faq_a3':
        'Submit a ticket through Account > Tickets > Create Ticket. Describe the issue and include photos if possible. Your TPS technician will be notified and can coordinate the repair.',
    'faq_q4': 'How do I contact my FCA coordinator?',
    'faq_a4':
        'Visit the Help Center (this page) to see your assigned FCA coordinator\'s contact information, including their phone number and email.',
    'faq_q5': 'What are geo-fence alerts?',
    'faq_a5':
        'Geo-fences are virtual boundaries set around designated farming areas. You\'ll receive an alert if a tractor moves outside its assigned geo-fence, helping prevent unauthorized usage.',
    'faq_q6': 'How do I change the app language?',
    'faq_a6':
        'Go to Account > Language, then choose between English and Filipino (Tagalog). The change applies immediately across the entire app.',

    // About
    'about_tagline': 'Smart Tractor Management System',
    'about_mission_title': 'Our Mission',
    'about_mission_body':
        'TanodTractor empowers Filipino farmers and agricultural cooperatives through modern tractor fleet management. By combining real-time GPS tracking, digital booking, preventive maintenance scheduling, and performance analytics, we help maximize tractor utilization, reduce downtime, and improve the productivity of mechanized farming across the Philippines.',
    'about_what_title': 'What is TanodTractor?',
    'about_what_body':
        'TanodTractor is a comprehensive tractor monitoring and management platform designed for the Philippine agricultural sector. It connects Farmers\' Cooperative Associations (FCAs), Third-Party Service Providers (TPS), and government agencies into one streamlined digital ecosystem — ensuring that every tractor is tracked, maintained, and utilized efficiently.',
    'about_partners_title': 'IN PARTNERSHIP WITH',
    'partner_leads_desc':
        'A leading agricultural products company that drives innovation in farming solutions and mechanization support across the Philippines.',
    'partner_philmech_desc':
        'The government agency under the Department of Agriculture responsible for developing and promoting postharvest technologies and agricultural mechanization nationwide.',
    'partner_da_desc':
        'The principal government agency responsible for the promotion of agricultural and fisheries development, food security, and poverty alleviation in rural areas.',
    'about_features_title': 'KEY FEATURES',
    'feature_tracking': 'Real-time GPS Tractor Tracking',
    'feature_booking': 'Digital Tractor Booking System',
    'feature_maintenance': 'Preventive Maintenance Scheduling (PMS)',
    'feature_geofence': 'Geo-fence Monitoring & Alerts',
    'feature_reports': 'Comprehensive Reports & Analytics',
    'feature_alerts': 'Real-time Alerts & Notifications',
    'about_footer':
        'TanodTractor — Empowering Philippine Agriculture\nthrough Smart Mechanization',

    // Terms & Privacy
    'tp_subtitle': 'Your rights and our responsibilities',
    'tp_tab_terms': 'Terms of Service',
    'tp_tab_privacy': 'Privacy Policy',
    'tp_effective_date': 'Effective: April 1, 2026',
    'tp_contact_footer':
        'Questions? Email us at support@tanodtractor.com',

    // Terms of Service
    'tos_1_title': 'Acceptance of Terms',
    'tos_1_body':
        'By downloading, installing, or using TanodTractor, you agree to be bound by these Terms of Service. If you do not agree, you must uninstall the application and discontinue use immediately. These terms constitute a legally binding agreement between you and Leads Agricultural Products Corporation.',
    'tos_2_title': 'Eligibility',
    'tos_2_body':
        'You must be at least 18 years of age and a duly authorized representative of a Farmers\' Cooperative Association (FCA), a Third-Party Service Provider (TPS), or an authorized government agency personnel to use this application. By using TanodTractor, you represent that you meet these requirements.',
    'tos_3_title': 'Account Responsibilities',
    'tos_3_body':
        'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You must notify us immediately of any unauthorized access. Sharing login credentials is strictly prohibited and may result in account suspension.',
    'tos_4_title': 'Permitted Use',
    'tos_4_body':
        'TanodTractor is provided solely for agricultural tractor fleet management, including GPS tracking, booking, maintenance scheduling, and reporting. You agree not to: (a) use the app for any unlawful purpose; (b) attempt to reverse-engineer, decompile, or tamper with the application; (c) upload malicious content or interfere with system operations; (d) use automated scripts to access the service.',
    'tos_5_title': 'GPS & Location Data',
    'tos_5_body':
        'TanodTractor collects real-time GPS data from registered tractors. By using the service, you consent to the collection and processing of location data for fleet monitoring, geo-fence enforcement, and operational reporting purposes. Location tracking operates continuously while the device is active.',
    'tos_6_title': 'Intellectual Property',
    'tos_6_body':
        'All content, trademarks, logos, and software within TanodTractor are the property of Leads Agricultural Products Corporation and its licensors. You are granted a limited, non-exclusive, non-transferable license to use the application. No part of the app may be reproduced or distributed without prior written consent.',
    'tos_7_title': 'Limitation of Liability',
    'tos_7_body':
        'TanodTractor is provided "as is" without warranties of any kind. We shall not be liable for any indirect, incidental, consequential, or punitive damages arising from your use of the service, including but not limited to loss of data, equipment damage, or service interruptions. Our total liability shall not exceed the fees paid by you in the preceding 12 months.',
    'tos_8_title': 'Termination',
    'tos_8_body':
        'We reserve the right to suspend or terminate your account at any time for violations of these terms, including misuse of equipment data, unauthorized access attempts, or conduct detrimental to the platform. Upon termination, your right to use the application ceases immediately.',
    'tos_9_title': 'Governing Law',
    'tos_9_body':
        'These Terms shall be governed by and construed in accordance with the laws of the Republic of the Philippines. Any disputes arising under these terms shall be subject to the exclusive jurisdiction of the courts of the Republic of the Philippines. This includes compliance with Republic Act No. 10173 (Data Privacy Act of 2012) and related regulations.',
    'tos_10_title': 'Changes to Terms',
    'tos_10_body':
        'We may update these Terms of Service from time to time. Continued use of TanodTractor after changes are posted constitutes your acceptance of the revised terms. We will notify you of material changes through in-app notifications or email.',

    // Privacy Policy
    'pp_1_title': 'Information We Collect',
    'pp_1_body':
        'We collect the following information:\n\n• Personal Information: name, email address, phone number, role, and cooperative/organization affiliation.\n• Device Information: device type, operating system, unique device identifiers, and push notification tokens.\n• Location Data: real-time GPS coordinates of registered tractors and device location.\n• Usage Data: app interactions, feature usage, login timestamps, and error logs.\n• Booking & Maintenance Records: tractor usage schedules, service history, and performance metrics.',
    'pp_2_title': 'How We Use Your Information',
    'pp_2_body':
        'Your information is used to:\n\n• Provide and operate the tractor management service.\n• Enable real-time GPS tracking and geo-fence monitoring.\n• Process bookings and maintenance schedules.\n• Send alerts, notifications, and service updates.\n• Generate reports and analytics for fleet optimization.\n• Verify identity and prevent unauthorized access.\n• Comply with legal obligations under Philippine law.',
    'pp_3_title': 'Data Sharing & Disclosure',
    'pp_3_body':
        'We may share your data with:\n\n• Partner Agencies: PHilMech and the Department of Agriculture for program monitoring and reporting.\n• Your FCA/TPS Organization: relevant operational data visible to your cooperative or service provider.\n• Service Providers: trusted third-party services (cloud hosting, push notifications, analytics) under strict data processing agreements.\n• Legal Authorities: when required by Philippine law, court order, or to protect rights and safety.\n\nWe do not sell your personal data to third parties.',
    'pp_4_title': 'Data Retention',
    'pp_4_body':
        'Personal data is retained for the duration of your account\'s active status plus five (5) years after account deactivation, in compliance with Republic Act No. 10173 (Data Privacy Act of 2012) and National Privacy Commission guidelines. GPS and usage logs are retained for three (3) years for reporting and audit purposes.',
    'pp_5_title': 'Data Security',
    'pp_5_body':
        'We implement industry-standard security measures including:\n\n• Encrypted data transmission (TLS/SSL).\n• Secure server infrastructure with firewall protection.\n• Role-based access controls.\n• Regular security audits and vulnerability assessments.\n• Token-based authentication (Laravel Sanctum).\n\nWhile we strive to protect your data, no electronic transmission or storage method is 100% secure.',
    'pp_6_title': 'Your Rights Under Philippine Law',
    'pp_6_body':
        'Under Republic Act No. 10173 (Data Privacy Act of 2012), you have the right to:\n\n• Be Informed — know how your data is collected and used.\n• Access — obtain a copy of your personal data.\n• Rectification — correct inaccurate or incomplete data.\n• Erasure — request deletion of your data (subject to legal retention requirements).\n• Object — refuse processing of your data under certain conditions.\n• Data Portability — receive your data in a structured, machine-readable format.\n• File a Complaint — lodge a complaint with the National Privacy Commission (NPC).',
    'pp_7_title': 'Children\'s Privacy',
    'pp_7_body':
        'TanodTractor is not intended for use by individuals under 18 years of age. We do not knowingly collect personal information from children. If we learn that we have collected data from a minor, we will take steps to delete it promptly. This complies with both Philippine Data Privacy Act requirements and Google Play/Apple App Store policies for child safety.',
    'pp_8_title': 'Third-Party Services',
    'pp_8_body':
        'TanodTractor integrates with third-party services that have their own privacy policies:\n\n• Google Maps / Google Play Services — for mapping and location.\n• Firebase Cloud Messaging — for push notifications.\n• Apple Push Notification Service — for iOS notifications.\n\nWe recommend reviewing the privacy policies of these services. We are not responsible for the data practices of third-party providers.',
    'pp_9_title': 'Changes to This Policy',
    'pp_9_body':
        'We may update this Privacy Policy to reflect changes in our practices or legal requirements. We will notify you of significant changes through in-app notifications. Your continued use of TanodTractor after such changes constitutes acceptance of the updated policy.',
    'pp_10_title': 'Contact Us',
    'pp_10_body':
        'For privacy-related inquiries or to exercise your rights under the Data Privacy Act, contact us:\n\n• Email: support@tanodtractor.com\n• Phone: +63 912 345 6789\n• Data Protection Officer: dpo@tanodtractor.com\n• National Privacy Commission: https://www.privacy.gov.ph',
  };

  // ─── Filipino (Tagalog) ───
  static const Map<String, String> _fil = {
    // Bottom nav
    'nav_home': 'Bahay',
    'nav_alerts': 'Alerto',
    'nav_booking': 'Booking',
    'nav_tps': 'TPS',
    'nav_farmers': 'Magsasaka',
    'nav_account': 'Account',

    // Account – sections
    'section_account': 'ACCOUNT',
    'section_services': 'SERBISYO',
    'section_support': 'SUPORTA',

    // Account – menu items
    'edit_profile': 'I-edit ang Profile',
    'change_password': 'Palitan ang Password',
    'phone_number': 'Numero ng Telepono',
    'verified': 'Na-verify',
    'not_verified': 'Hindi na-verify',
    'tickets': 'Mga Ticket',
    'maintenance': 'Maintenance',
    'geo_fences': 'Geo Fences',
    'feedback': 'Feedback',
    'reports': 'Mga Ulat',
    'language': 'Wika',
    'help_center': 'Sentro ng Tulong',
    'about_tanod': 'Tungkol sa TanodTractor',
    'terms_privacy': 'Mga Tuntunin at Privacy',
    'sign_out': 'Mag-sign Out',
    'sign_out_message':
        'Sigurado ka bang gusto mong mag-sign out sa iyong account?',
    'app_version': 'TanodTractor v1.0.0',

    // Account deletion
    'delete_account': 'Tanggalin ang Account',
    'delete_account_title': 'Pagtanggal ng Account',
    'delete_account_warning_title': 'Hindi na ito maibabalik',
    'delete_account_warning_body':
        'Ang pagtanggal ng iyong account ay permanenteng mag-aalis ng lahat ng iyong datos, kasama ang iyong profile, mga booking, traktora, at kasaysayan ng aktibidad. Hindi na ito maibabalik.',
    'delete_account_grace_title': 'Ano ang mangyayari?',
    'delete_account_grace_body':
        'Ang iyong account ay iiskedyul para tanggalin pagkatapos ng 7 araw na grace period. Sa panahong ito, maaari ka pa ring mag-sign in at kanselahin ang request.',
    'delete_account_notify_body':
        'Isang confirmation email at SMS ang ipapadala para ipaalam sa iyo ang naka-iskedyul na pagtanggal.',
    'delete_account_password_label': 'Ilagay ang iyong password para kumpirmahin',
    'delete_account_password_hint': 'Kasalukuyang password',
    'delete_account_confirm': 'Tanggalin ang Aking Account',
    'delete_account_cancel': 'Kanselahin ang Pagtanggal',
    'delete_account_success':
        'Na-request na ang pagtanggal ng account. Mayroon kang 7 araw para kanselahin.',
    'delete_account_cancel_success': 'Nakansela na ang pagtanggal ng account.',
    'delete_account_pending_title': 'Naka-iskedyul ang Pagtanggal',
    'delete_account_pending_body':
        'Ang iyong account ay naka-iskedyul para sa permanenteng pagtanggal sa:',
    'delete_account_pending_cancel_info':
        'Maaari mong kanselahin ang request na ito bago ang petsa sa itaas para panatilihin ang iyong account.',
    'delete_account_days_remaining': 'araw na natitira',
    'delete_account_confirm_dialog_title': 'Kumpirmahin ang Pagtanggal',
    'delete_account_confirm_dialog_message':
        'Iiskedyul nito ang iyong account para sa permanenteng pagtanggal sa loob ng 7 araw. Sigurado ka ba?',

    // Language picker
    'select_language': 'Pumili ng Wika',
    'english': 'English',
    'tagalog': 'Filipino (Tagalog)',

    // Common
    'cancel': 'Kanselahin',
    'confirm': 'Kumpirmahin',
    'save': 'I-save',
    'delete': 'Burahin',
    'search': 'Maghanap',
    'loading': 'Naglo-load...',
    'no_data': 'Walang datos',
    'error': 'May nangyaring mali',
    'retry': 'Subukan muli',
    'success': 'Tagumpay',

    // Help Center
    'help_center_subtitle': 'Humingi ng tulong at makipag-ugnayan sa iyong support team',
    'your_fca': 'Iyong FCA Coordinator',
    'assigned_tps': 'Mga Nakatalagang TPS Technician',
    'system_support': 'System Support',
    'fca_label': 'FCA',
    'tps_label': 'TPS',
    'admin_label': 'SUPPORT',
    'quick_help': 'Mabilis na Tulong',

    // TPS Distribution
    'distribute_tractor': 'Ipamahagi ang Tractor',
    'create_ticket': 'Gumawa ng Ticket',
    'distribute_tractor_subtitle': 'Italaga ang tractor sa isang FCA',
    'select_tractor': 'Pumili ng Tractor',
    'select_tractor_hint': 'Pumili ng tractor na ipapamahagi',
    'tractor_already_distributed': 'Naipamahagi na',
    'select_fca': 'Pumili ng FCA',
    'select_fca_hint': 'Pumili ng FCA na tatanggap',
    'distribution_area': 'Lugar / Lokasyon',
    'distribution_area_hint': 'hal. Brgy. San Jose, Tarlac',
    'distribution_date': 'Petsa ng Pamamahagi',
    'distribution_notes': 'Mga Tala (opsyonal)',
    'distribution_notes_hint': 'Karagdagang mga puna...',
    'distribute_submit': 'Ipamahagi ang Tractor',
    'distribute_success': 'Matagumpay na naipamahagi ang tractor!',
    'distribute_error': 'Hindi maipamahagi ang tractor.',
    'no_tractors_available': 'Walang available na tractor para ipamahagi.',
    'no_fca_users_available': 'Walang available na FCA user.',

    'help_tickets_title': 'Magsumite ng Ticket',
    'help_tickets_desc':
        'Mag-report ng problema o humiling ng tulong sa pamamagitan ng ticket system.',
    'help_call_title': 'Tumawag sa Support',
    'help_call_desc':
        'Direktang makipag-ugnayan sa aming support team para sa mga urgent na concern.',
    'help_hours_title': 'Oras ng Operasyon',
    'help_hours_desc': 'Lunes – Biyernes, 8:00 AM – 5:00 PM (PHT)',

    // FAQ
    'faq_title': 'Mga Madalas na Tanong',
    'faq_q1': 'Paano mag-book ng tractor?',
    'faq_a1':
        'Pumunta sa Booking tab, pumili ng available na tractor, piliin ang gusto mong petsa at time slot, punan ang layunin at lugar, pagkatapos ay isumite ang booking request. Ire-review at aapprove-an ito ng iyong FCA.',
    'faq_q2': 'Paano ko masusubaybayan ang aking tractor nang real-time?',
    'faq_a2':
        'Buksan ang Home tab para makita ang lahat ng nakatalagang tractor sa mapa. I-tap ang kahit anong tractor para makita ang live location, bilis, at kasalukuyang status nito.',
    'faq_q3': 'Ano ang gagawin ko kapag nasira ang tractor?',
    'faq_a3':
        'Magsumite ng ticket sa Account > Tickets > Create Ticket. Ilarawan ang problema at maglagay ng mga litrato kung maaari. Aabisuhan ang iyong TPS technician at magko-coordinate para sa pag-aayos.',
    'faq_q4': 'Paano ko makokontak ang aking FCA coordinator?',
    'faq_a4':
        'Bisitahin ang Help Center (itong page) para makita ang contact information ng iyong nakatalagang FCA coordinator, kasama ang kanilang numero ng telepono at email.',
    'faq_q5': 'Ano ang geo-fence alerts?',
    'faq_a5':
        'Ang mga geo-fence ay mga virtual na hangganan na naka-set sa paligid ng mga itinalagang lugar ng pagsasaka. Makakatanggap ka ng alerto kapag lumabas ang tractor sa itinalagang geo-fence, na tumutulong maiwasan ang hindi awtorisadong paggamit.',
    'faq_q6': 'Paano palitan ang wika ng app?',
    'faq_a6':
        'Pumunta sa Account > Wika, pagkatapos ay pumili sa pagitan ng English at Filipino (Tagalog). Agad na mag-a-apply ang pagbabago sa buong app.',

    // About
    'about_tagline': 'Smart na Pamamahala ng Tractor',
    'about_mission_title': 'Aming Misyon',
    'about_mission_body':
        'Pinapalakas ng TanodTractor ang mga Pilipinong magsasaka at agricultural cooperatives sa pamamagitan ng modernong pamamahala ng tractor fleet. Sa pagsasama ng real-time GPS tracking, digital booking, preventive maintenance scheduling, at performance analytics, tinutulungan namin na ma-maximize ang paggamit ng tractor, mabawasan ang downtime, at mapabuti ang produktibidad ng mekanisadong pagsasaka sa buong Pilipinas.',
    'about_what_title': 'Ano ang TanodTractor?',
    'about_what_body':
        'Ang TanodTractor ay isang komprehensibong tractor monitoring at management platform na dinisenyo para sa sektor ng agrikultura sa Pilipinas. Ikinokonekta nito ang mga Farmers\' Cooperative Associations (FCAs), Third-Party Service Providers (TPS), at mga ahensya ng gobyerno sa isang streamlined na digital ecosystem — tinitiyak na ang bawat tractor ay namo-monitor, namemaintain, at nagagamit nang mahusay.',
    'about_partners_title': 'SA PAKIKIPAGTULUNGAN NG',
    'partner_leads_desc':
        'Isang nangungunang kumpanya ng agricultural products na nagdadala ng inobasyon sa mga solusyon sa pagsasaka at mekanisasyon sa buong Pilipinas.',
    'partner_philmech_desc':
        'Ang ahensya ng gobyerno sa ilalim ng Department of Agriculture na responsable sa pagbuo at pagsusulong ng postharvest technologies at agricultural mechanization sa buong bansa.',
    'partner_da_desc':
        'Ang pangunahing ahensya ng gobyerno na responsable sa pagsusulong ng agricultural at fisheries development, food security, at poverty alleviation sa mga rural na lugar.',
    'about_features_title': 'MGA TAMPOK',
    'feature_tracking': 'Real-time GPS Tractor Tracking',
    'feature_booking': 'Digital na Sistema ng Pag-book ng Tractor',
    'feature_maintenance': 'Preventive Maintenance Scheduling (PMS)',
    'feature_geofence': 'Geo-fence Monitoring at Alerto',
    'feature_reports': 'Komprehensibong Mga Ulat at Analytics',
    'feature_alerts': 'Real-time na Mga Alerto at Notipikasyon',
    'about_footer':
        'TanodTractor — Pinapalakas ang Agrikultura ng Pilipinas\nsa pamamagitan ng Smart na Mekanisasyon',

    // Terms & Privacy
    'tp_subtitle': 'Ang iyong mga karapatan at aming mga responsibilidad',
    'tp_tab_terms': 'Mga Tuntunin ng Serbisyo',
    'tp_tab_privacy': 'Patakaran sa Privacy',
    'tp_effective_date': 'Epektibo: Abril 1, 2026',
    'tp_contact_footer':
        'May katanungan? I-email kami sa support@tanodtractor.com',

    // Terms of Service
    'tos_1_title': 'Pagtanggap ng mga Tuntunin',
    'tos_1_body':
        'Sa pag-download, pag-install, o paggamit ng TanodTractor, sumasang-ayon ka na sumunod sa mga Tuntunin ng Serbisyong ito. Kung hindi ka sumasang-ayon, kailangan mong i-uninstall ang application at ihinto kaagad ang paggamit. Ang mga tuntuning ito ay bumubuo ng isang legal na kasunduan sa pagitan mo at ng Leads Agricultural Products Corporation.',
    'tos_2_title': 'Kwalipikasyon',
    'tos_2_body':
        'Dapat ay hindi bababa sa 18 taong gulang ka at isang awtorisadong kinatawan ng isang Farmers\' Cooperative Association (FCA), Third-Party Service Provider (TPS), o awtorisadong tauhan ng ahensya ng gobyerno upang magamit ang application na ito. Sa paggamit ng TanodTractor, kinakatawan mo na natutugunan mo ang mga pangangailangang ito.',
    'tos_3_title': 'Responsibilidad sa Account',
    'tos_3_body':
        'Responsable ka sa pagpapanatili ng pagiging kompidensiyal ng iyong account credentials at sa lahat ng aktibidad na nangyayari sa ilalim ng iyong account. Dapat mo kaming abisuhan kaagad ng anumang hindi awtorisadong pag-access. Ang pagbabahagi ng login credentials ay mahigpit na ipinagbabawal at maaaring magresulta sa suspensyon ng account.',
    'tos_4_title': 'Pinapahintulutang Paggamit',
    'tos_4_body':
        'Ang TanodTractor ay ibinibigay lamang para sa pamamahala ng agricultural tractor fleet, kabilang ang GPS tracking, booking, maintenance scheduling, at pag-uulat. Sumasang-ayon ka na hindi: (a) gagamitin ang app para sa anumang labag sa batas na layunin; (b) susubukang i-reverse-engineer, i-decompile, o pakialaman ang application; (c) mag-upload ng malisyosong content o manghimasok sa operasyon ng system; (d) gumamit ng automated scripts para ma-access ang serbisyo.',
    'tos_5_title': 'GPS at Location Data',
    'tos_5_body':
        'Ang TanodTractor ay kumukuha ng real-time GPS data mula sa mga nakarehistrong tractor. Sa paggamit ng serbisyo, pumapayag ka sa pagkuha at pagproseso ng location data para sa fleet monitoring, geo-fence enforcement, at operational reporting na mga layunin. Ang location tracking ay tumatakbo nang tuloy-tuloy habang aktibo ang device.',
    'tos_6_title': 'Intellectual Property',
    'tos_6_body':
        'Ang lahat ng content, trademark, logo, at software sa loob ng TanodTractor ay pag-aari ng Leads Agricultural Products Corporation at mga licensor nito. Binibigyan ka ng limitado, hindi eksklusibo, at hindi maililipat na lisensya upang gamitin ang application. Walang bahagi ng app ang maaaring kopyahin o ipamahagi nang walang nakasulat na pahintulot.',
    'tos_7_title': 'Limitasyon ng Pananagutan',
    'tos_7_body':
        'Ang TanodTractor ay ibinibigay "as is" nang walang anumang garantiya. Hindi kami mananagot para sa anumang hindi direkta, incidental, consequential, o punitive na pinsala na nagmumula sa iyong paggamit ng serbisyo, kabilang ngunit hindi limitado sa pagkawala ng data, pinsala sa kagamitan, o pagkakaantala ng serbisyo.',
    'tos_8_title': 'Pagwawakas',
    'tos_8_body':
        'Nakalaan sa amin ang karapatang i-suspend o wakasan ang iyong account sa anumang oras para sa mga paglabag sa mga tuntuning ito, kabilang ang maling paggamit ng data ng kagamitan, mga hindi awtorisadong pagtatangka sa pag-access, o pag-uugali na nakakapinsala sa platform. Sa pagwawakas, ang iyong karapatang gamitin ang application ay agad na nagtatapos.',
    'tos_9_title': 'Namamahalang Batas',
    'tos_9_body':
        'Ang mga Tuntuning ito ay pinamamahalaan at binibigyang-kahulugan alinsunod sa mga batas ng Republika ng Pilipinas. Ang anumang hindi pagkakaunawaan na lumitaw sa ilalim ng mga tuntuning ito ay sasailalim sa eksklusibong hurisdiksyon ng mga korte ng Republika ng Pilipinas. Kabilang dito ang pagsunod sa Republic Act No. 10173 (Data Privacy Act of 2012) at mga kaugnay na regulasyon.',
    'tos_10_title': 'Mga Pagbabago sa Tuntunin',
    'tos_10_body':
        'Maaari naming i-update ang mga Tuntunin ng Serbisyong ito paminsan-minsan. Ang patuloy na paggamit ng TanodTractor pagkatapos mai-post ang mga pagbabago ay nangangahulugang tinatanggap mo ang mga binagong tuntunin. Aabisuhan ka namin ng mga mahahalagang pagbabago sa pamamagitan ng in-app notifications o email.',

    // Privacy Policy
    'pp_1_title': 'Impormasyong Kinokolekta Namin',
    'pp_1_body':
        'Kinokolekta namin ang sumusunod na impormasyon:\n\n• Personal na Impormasyon: pangalan, email address, numero ng telepono, tungkulin, at kaanib na kooperatiba/organisasyon.\n• Impormasyon ng Device: uri ng device, operating system, natatanging device identifiers, at push notification tokens.\n• Location Data: real-time GPS coordinates ng mga nakarehistrong tractor at lokasyon ng device.\n• Usage Data: mga interaksyon sa app, paggamit ng feature, login timestamps, at error logs.\n• Booking at Maintenance Records: mga iskedyul ng paggamit ng tractor, kasaysayan ng serbisyo, at mga sukatan ng pagganap.',
    'pp_2_title': 'Paano Namin Ginagamit ang Iyong Impormasyon',
    'pp_2_body':
        'Ang iyong impormasyon ay ginagamit upang:\n\n• Ibigay at patakbuhin ang serbisyo sa pamamahala ng tractor.\n• Paganahin ang real-time GPS tracking at geo-fence monitoring.\n• Iproseso ang mga booking at maintenance schedule.\n• Magpadala ng mga alerto, notipikasyon, at update sa serbisyo.\n• Bumuo ng mga ulat at analytics para sa fleet optimization.\n• I-verify ang pagkakakilanlan at maiwasan ang hindi awtorisadong pag-access.\n• Sumunod sa mga legal na obligasyon sa ilalim ng batas ng Pilipinas.',
    'pp_3_title': 'Pagbabahagi at Pagsisiwalat ng Data',
    'pp_3_body':
        'Maaari naming ibahagi ang iyong data sa:\n\n• Mga Partner na Ahensya: PHilMech at Department of Agriculture para sa program monitoring at pag-uulat.\n• Iyong FCA/TPS na Organisasyon: mga kaugnay na operational data na nakikita ng iyong kooperatiba o service provider.\n• Mga Service Provider: mga pinagkakatiwalaang third-party na serbisyo (cloud hosting, push notifications, analytics) sa ilalim ng mahigpit na data processing agreements.\n• Mga Legal na Awtoridad: kapag kinakailangan ng batas ng Pilipinas, utos ng korte, o upang protektahan ang mga karapatan at kaligtasan.\n\nHindi namin ibinebenta ang iyong personal na data sa mga third party.',
    'pp_4_title': 'Pagpapanatili ng Data',
    'pp_4_body':
        'Ang personal na data ay pinapanatili sa buong tagal ng aktibong status ng iyong account kasama ang limang (5) taon pagkatapos ma-deactivate ang account, alinsunod sa Republic Act No. 10173 (Data Privacy Act of 2012) at mga alituntunin ng National Privacy Commission. Ang GPS at usage logs ay pinapanatili ng tatlong (3) taon para sa pag-uulat at pag-audit.',
    'pp_5_title': 'Seguridad ng Data',
    'pp_5_body':
        'Nagpapatupad kami ng mga industry-standard na hakbang sa seguridad kabilang ang:\n\n• Naka-encrypt na data transmission (TLS/SSL).\n• Secure na server infrastructure na may firewall protection.\n• Role-based access controls.\n• Regular na security audits at vulnerability assessments.\n• Token-based authentication (Laravel Sanctum).\n\nBagaman sinisikap naming protektahan ang iyong data, walang electronic transmission o storage method na 100% secure.',
    'pp_6_title': 'Mga Karapatan Mo sa Ilalim ng Batas ng Pilipinas',
    'pp_6_body':
        'Sa ilalim ng Republic Act No. 10173 (Data Privacy Act of 2012), may karapatan ka na:\n\n• Malaman — kung paano kinokolekta at ginagamit ang iyong data.\n• Ma-access — kumuha ng kopya ng iyong personal na data.\n• Ipatama — itama ang hindi tumpak o hindi kumpletong data.\n• Burahin — humiling ng pagbura ng iyong data (sa ilalim ng mga kinakailangan sa legal na pagpapanatili).\n• Tumutol — tanggihan ang pagproseso ng iyong data sa ilalim ng mga tiyak na kondisyon.\n• Data Portability — tanggapin ang iyong data sa isang structured, machine-readable na format.\n• Maghain ng Reklamo — maghain ng reklamo sa National Privacy Commission (NPC).',
    'pp_7_title': 'Privacy ng mga Bata',
    'pp_7_body':
        'Ang TanodTractor ay hindi nilayon para sa paggamit ng mga indibidwal na wala pang 18 taong gulang. Hindi kami sadyang kumukuha ng personal na impormasyon mula sa mga bata. Kung malaman naming nakakolekta kami ng data mula sa isang menor de edad, gagawa kami ng mga hakbang upang agad itong burahin.',
    'pp_8_title': 'Mga Third-Party na Serbisyo',
    'pp_8_body':
        'Ang TanodTractor ay nag-iintegrate sa mga third-party na serbisyo na may sariling mga patakaran sa privacy:\n\n• Google Maps / Google Play Services — para sa mapa at lokasyon.\n• Firebase Cloud Messaging — para sa push notifications.\n• Apple Push Notification Service — para sa iOS notifications.\n\nInirerekomenda naming suriin ang mga patakaran sa privacy ng mga serbisyong ito.',
    'pp_9_title': 'Mga Pagbabago sa Patakarang Ito',
    'pp_9_body':
        'Maaari naming i-update ang Privacy Policy na ito upang maipakita ang mga pagbabago sa aming mga kasanayan o mga legal na kinakailangan. Aabisuhan ka namin ng mga mahahalagang pagbabago sa pamamagitan ng in-app notifications. Ang patuloy mong paggamit ng TanodTractor pagkatapos ng mga nasabing pagbabago ay nangangahulugang tinatanggap mo ang na-update na patakaran.',
    'pp_10_title': 'Makipag-ugnayan sa Amin',
    'pp_10_body':
        'Para sa mga katanungang nauugnay sa privacy o para magamit ang iyong mga karapatan sa ilalim ng Data Privacy Act, makipag-ugnayan sa amin:\n\n• Email: support@tanodtractor.com\n• Telepono: +63 912 345 6789\n• Data Protection Officer: dpo@tanodtractor.com\n• National Privacy Commission: https://www.privacy.gov.ph',
  };
}
