import '../config/local_config.dart';

// Data models mapped 1:1 to the tables in supabase_setup.sql.

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _intOrNull(Object? v) => v == null ? null : _int(v);
String _str(Object? v) => v == null ? '' : '$v';
bool _bool(Object? v) => v == true;
DateTime _date(Object? v) => v == null ? DateTime.now() : (DateTime.tryParse('$v') ?? DateTime.now()).toLocal();

// ───────────────── Staff ─────────────────

enum StaffRole {
  superAdmin('super_admin', 'مدير رئيسي'),
  manager('manager', 'مدير'),
  ordersClerk('orders_clerk', 'موظف طلبات');

  const StaffRole(this.code, this.label);

  final String code;
  final String label;

  static StaffRole? fromCode(Object? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }

  bool get canManageCatalog => this == superAdmin || this == manager;
  bool get canSeeDashboard => this == superAdmin || this == manager;
  bool get isSuper => this == superAdmin;
}

enum StaffStatus {
  pending('pending', 'بانتظار الموافقة'),
  active('active', 'فعّال'),
  suspended('suspended', 'موقوف');

  const StaffStatus(this.code, this.label);

  final String code;
  final String label;

  static StaffStatus fromCode(Object? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => StaffStatus.pending);
}

class Staff {
  const Staff({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String userId;
  final String email;
  final String fullName;
  final StaffRole? role;
  final StaffStatus status;
  final DateTime createdAt;

  bool get isActive => status == StaffStatus.active && role != null;

  String get displayName => fullName.trim().isEmpty ? email : fullName;

  factory Staff.fromMap(Map<String, dynamic> m) => Staff(
    userId: _str(m['user_id']),
    email: _str(m['email']),
    fullName: _str(m['full_name']),
    role: StaffRole.fromCode(m['role']),
    status: StaffStatus.fromCode(m['status']),
    createdAt: _date(m['created_at']),
  );
}

// ───────────────── Catalog ─────────────────

class Category {
  const Category({required this.id, required this.name, this.sortOrder = 0});

  final String id;
  final String name;
  final int sortOrder;

  factory Category.fromMap(Map<String, dynamic> m) =>
      Category(id: _str(m['id']), name: _str(m['name']), sortOrder: _int(m['sort_order']));
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.categoryId,
    required this.price,
    this.oldPrice,
    this.pages = 0,
    this.description = '',
    this.coverUrl,
    this.coverPath,
    this.coverImage,
    this.available = true,
    this.featured = false,
    this.isNew = false,
    this.bestSeller = false,
    this.specialOffer = false,
    this.popularity = 0,
    this.addedOn,
  });

  final String id;
  final String title;
  final String author;
  final String? categoryId;
  final int price;
  final int? oldPrice;
  final int pages;
  final String description;

  /// Public URL of the uploaded cover (Supabase Storage), or null for the drawn cover.
  final String? coverUrl;

  /// Path of the uploaded file inside the covers bucket (used to delete it).
  final String? coverPath;

  /// Asset file name used by the store app's built-in covers (legacy).
  final String? coverImage;
  final bool available;
  final bool featured;
  final bool isNew;
  final bool bestSeller;
  final bool specialOffer;
  final int popularity;
  final String? addedOn;

  bool get hasDiscount => oldPrice != null && oldPrice! > price;

  bool get hasUploadedCover => coverUrl != null && coverUrl!.trim().isNotEmpty;

  factory Book.fromMap(Map<String, dynamic> m) => Book(
    id: _str(m['id']),
    title: _str(m['title']),
    author: _str(m['author']),
    categoryId: m['category_id'] as String?,
    price: _int(m['price']),
    oldPrice: _intOrNull(m['old_price']),
    pages: _int(m['pages']),
    description: _str(m['description']),
    coverUrl: m['cover_url'] as String?,
    coverPath: m['cover_path'] as String?,
    coverImage: m['cover_image'] as String?,
    available: m['available'] != false,
    featured: _bool(m['featured']),
    isNew: _bool(m['is_new']),
    bestSeller: _bool(m['best_seller']),
    specialOffer: _bool(m['special_offer']),
    popularity: _int(m['popularity']),
    addedOn: m['added_on'] as String?,
  );
}

// ───────────────── Orders ─────────────────

enum OrderStatus {
  newOrder('new', 'جديد'),
  preparing('preparing', 'قيد التجهيز'),
  shipped('shipped', 'سُلّم لشركة التوصيل'),
  delivered('delivered', 'تم التسليم'),
  cancelled('cancelled', 'ملغي');

  const OrderStatus(this.code, this.label);

  final String code;
  final String label;

  static OrderStatus fromCode(Object? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => OrderStatus.newOrder);

  static String labelOf(Object? code) => code == null ? '—' : fromCode(code).label;
}

class StoreOrder {
  const StoreOrder({
    required this.id,
    required this.number,
    required this.customerName,
    required this.phone,
    required this.governorate,
    required this.address,
    required this.landmark,
    required this.notes,
    required this.booksTotal,
    required this.deliveryFee,
    required this.grandTotal,
    required this.itemCount,
    required this.status,
    required this.internalNote,
    required this.createdAt,
  });

  final String id;
  final String number;
  final String customerName;
  final String phone;
  final String governorate;
  final String address;
  final String landmark;
  final String notes;
  final int booksTotal;
  final int deliveryFee;
  final int grandTotal;
  final int itemCount;
  final OrderStatus status;
  final String internalNote;
  final DateTime createdAt;

  factory StoreOrder.fromMap(Map<String, dynamic> m) => StoreOrder(
    id: _str(m['id']),
    number: _str(m['order_number']),
    customerName: _str(m['customer_name']),
    phone: _str(m['phone']),
    governorate: _str(m['governorate']),
    address: _str(m['address']),
    landmark: _str(m['landmark']),
    notes: _str(m['notes']),
    booksTotal: _int(m['books_total']),
    deliveryFee: _int(m['delivery_fee']),
    grandTotal: _int(m['grand_total']),
    itemCount: _int(m['item_count']),
    status: OrderStatus.fromCode(m['status']),
    internalNote: _str(m['internal_note']),
    createdAt: _date(m['created_at']),
  );
}

class OrderItem {
  const OrderItem({
    required this.orderId,
    required this.bookId,
    required this.title,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  final String orderId;
  final String? bookId;
  final String title;
  final int unitPrice;
  final int quantity;
  final int lineTotal;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    orderId: _str(m['order_id']),
    bookId: m['book_id'] as String?,
    title: _str(m['title']),
    unitPrice: _int(m['unit_price']),
    quantity: _int(m['quantity']),
    lineTotal: _int(m['line_total']),
  );
}

class StatusChange {
  const StatusChange({
    required this.fromStatus,
    required this.toStatus,
    required this.changedByName,
    required this.changedAt,
  });

  final String? fromStatus;
  final String toStatus;
  final String changedByName;
  final DateTime changedAt;

  factory StatusChange.fromMap(Map<String, dynamic> m) => StatusChange(
    fromStatus: m['from_status'] as String?,
    toStatus: _str(m['to_status']),
    changedByName: _str(m['changed_by_name']),
    changedAt: _date(m['changed_at']),
  );
}

// ───────────────── Settings ─────────────────

class StoreSettings {
  const StoreSettings({
    this.whatsappNumber = LocalConfig.whatsappNumber,
    this.deliveryFeeNajaf = 3000,
    this.deliveryFeeOther = 5000,
    this.aboutText = '',
    this.announcement = '',
    this.announcementEnabled = false,
  });

  final String whatsappNumber;
  final int deliveryFeeNajaf;
  final int deliveryFeeOther;
  final String aboutText;
  final String announcement;
  final bool announcementEnabled;

  factory StoreSettings.fromMap(Map<String, dynamic> m) => StoreSettings(
    whatsappNumber: _str(m['whatsapp_number']),
    deliveryFeeNajaf: _int(m['delivery_fee_najaf']),
    deliveryFeeOther: _int(m['delivery_fee_other']),
    aboutText: _str(m['about_text']),
    announcement: _str(m['announcement']),
    announcementEnabled: _bool(m['announcement_enabled']),
  );

  Map<String, dynamic> toMap() => {
    'whatsapp_number': whatsappNumber,
    'delivery_fee_najaf': deliveryFeeNajaf,
    'delivery_fee_other': deliveryFeeOther,
    'about_text': aboutText,
    'announcement': announcement,
    'announcement_enabled': announcementEnabled,
  };
}
