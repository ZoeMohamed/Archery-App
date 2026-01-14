import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ClassStatus { upcoming, ongoing, completed }

class ClassSchedule {
  final String id;
  final String className;
  final String coach;
  final DateTime dateTime;
  final String duration;
  final String location;
  final int maxParticipants;
  final int currentParticipants;
  final ClassStatus status;
  final bool isEnrolled;
  final bool hasAttended;

  ClassSchedule({
    required this.id,
    required this.className,
    required this.coach,
    required this.dateTime,
    required this.duration,
    required this.location,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.status,
    this.isEnrolled = false,
    this.hasAttended = false,
  });
}

class KelasScreen extends StatefulWidget {
  const KelasScreen({super.key});

  @override
  State<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends State<KelasScreen> {
  List<ClassSchedule> _classes = [];
  String _selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  void _loadClasses() {
    // Demo data - Nantinya kelas dibuat oleh pelatih
    setState(() {
      _classes = [
        ClassSchedule(
          id: 'class-001',
          className: 'Teknik Dasar Recurve',
          coach: 'Coach Ahmad',
          dateTime: DateTime(2026, 1, 18, 9, 0),
          duration: '2 jam',
          location: 'Lapangan Utama',
          maxParticipants: 15,
          currentParticipants: 12,
          status: ClassStatus.upcoming,
          isEnrolled: true,
        ),
        ClassSchedule(
          id: 'class-002',
          className: 'Latihan Form & Postur',
          coach: 'Coach Budi',
          dateTime: DateTime(2026, 1, 19, 14, 0),
          duration: '1.5 jam',
          location: 'Lapangan Indoor',
          maxParticipants: 10,
          currentParticipants: 8,
          status: ClassStatus.upcoming,
          isEnrolled: false,
        ),
        ClassSchedule(
          id: 'class-003',
          className: 'Pelatihan Mental & Konsentrasi',
          coach: 'Coach Siti',
          dateTime: DateTime(2026, 1, 14, 10, 0),
          duration: '2 jam',
          location: 'Ruang Meeting',
          maxParticipants: 20,
          currentParticipants: 18,
          status: ClassStatus.ongoing,
          isEnrolled: true,
        ),
        ClassSchedule(
          id: 'class-004',
          className: 'Teknik Lanjutan Compound',
          coach: 'Coach Rudi',
          dateTime: DateTime(2026, 1, 13, 15, 0),
          duration: '2 jam',
          location: 'Lapangan Utama',
          maxParticipants: 12,
          currentParticipants: 10,
          status: ClassStatus.completed,
          isEnrolled: true,
          hasAttended: true,
        ),
        ClassSchedule(
          id: 'class-005',
          className: 'Strategi Kompetisi',
          coach: 'Coach Ahmad',
          dateTime: DateTime(2026, 1, 11, 9, 0),
          duration: '3 jam',
          location: 'Lapangan Utama',
          maxParticipants: 15,
          currentParticipants: 14,
          status: ClassStatus.completed,
          isEnrolled: true,
          hasAttended: false,
        ),
      ];
    });
  }

  List<ClassSchedule> get filteredClasses {
    if (_selectedFilter == 'Semua') return _classes;

    ClassStatus? filterStatus;
    switch (_selectedFilter) {
      case 'Akan Datang':
        filterStatus = ClassStatus.upcoming;
        break;
      case 'Berlangsung':
        filterStatus = ClassStatus.ongoing;
        break;
      case 'Selesai':
        filterStatus = ClassStatus.completed;
        break;
    }

    return _classes.where((c) => c.status == filterStatus).toList();
  }

  void _enrollClass(int index) {
    setState(() {
      final classItem = _classes[index];
      _classes[index] = ClassSchedule(
        id: classItem.id,
        className: classItem.className,
        coach: classItem.coach,
        dateTime: classItem.dateTime,
        duration: classItem.duration,
        location: classItem.location,
        maxParticipants: classItem.maxParticipants,
        currentParticipants: classItem.currentParticipants + 1,
        status: classItem.status,
        isEnrolled: true,
        hasAttended: classItem.hasAttended,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Berhasil mendaftar kelas!'),
        backgroundColor: Color(0xFF10B982),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelEnrollment(int index) {
    setState(() {
      final classItem = _classes[index];
      _classes[index] = ClassSchedule(
        id: classItem.id,
        className: classItem.className,
        coach: classItem.coach,
        dateTime: classItem.dateTime,
        duration: classItem.duration,
        location: classItem.location,
        maxParticipants: classItem.maxParticipants,
        currentParticipants: classItem.currentParticipants - 1,
        status: classItem.status,
        isEnrolled: false,
        hasAttended: classItem.hasAttended,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pendaftaran kelas dibatalkan'),
        backgroundColor: Color(0xFFEF4444),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enrolledCount = _classes.where((c) => c.isEnrolled).length;
    final attendedCount = _classes.where((c) => c.hasAttended).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B982),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kelas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF10B982), Color(0xFF059669)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(
                      'Kelas Terdaftar',
                      enrolledCount.toString(),
                      Icons.class_,
                    ),
                    _buildStatCard(
                      'Kehadiran',
                      attendedCount.toString(),
                      Icons.check_circle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Akan Datang'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Berlangsung'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Selesai'),
                ],
              ),
            ),
          ),
          // Classes List
          Expanded(
            child: filteredClasses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada kelas',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kelas akan dibuat oleh pelatih',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredClasses.length,
                    itemBuilder: (context, index) {
                      final classItem = filteredClasses[index];
                      final actualIndex = _classes.indexOf(classItem);
                      return _buildClassCard(classItem, actualIndex);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: const Color(0xFF10B982),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildClassCard(ClassSchedule classItem, int index) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (classItem.status) {
      case ClassStatus.upcoming:
        statusColor = const Color(0xFF3B82F6);
        statusText = 'Akan Datang';
        statusIcon = Icons.schedule;
        break;
      case ClassStatus.ongoing:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Berlangsung';
        statusIcon = Icons.play_circle;
        break;
      case ClassStatus.completed:
        statusColor = const Color(0xFF6B7280);
        statusText = 'Selesai';
        statusIcon = Icons.check_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: classItem.isEnrolled
            ? Border.all(color: const Color(0xFF10B982), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    classItem.className,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  classItem.coach,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B982),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(classItem.dateTime),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('HH:mm').format(classItem.dateTime)} (${classItem.duration})',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  classItem.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value:
                        classItem.currentParticipants /
                        classItem.maxParticipants,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      classItem.currentParticipants >= classItem.maxParticipants
                          ? Colors.red
                          : const Color(0xFF10B982),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${classItem.currentParticipants}/${classItem.maxParticipants}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            if (classItem.status == ClassStatus.completed &&
                classItem.isEnrolled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: classItem.hasAttended
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      classItem.hasAttended ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: classItem.hasAttended
                          ? const Color(0xFF10B982)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      classItem.hasAttended ? 'Hadir' : 'Tidak Hadir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: classItem.hasAttended
                            ? const Color(0xFF065F46)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (classItem.status == ClassStatus.upcoming) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: classItem.isEnrolled
                    ? OutlinedButton.icon(
                        onPressed: () => _cancelEnrollment(index),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Batalkan Pendaftaran'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed:
                            classItem.currentParticipants >=
                                classItem.maxParticipants
                            ? null
                            : () => _enrollClass(index),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: Text(
                          classItem.currentParticipants >=
                                  classItem.maxParticipants
                              ? 'Kelas Penuh'
                              : 'Daftar Kelas',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B982),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[500],
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
