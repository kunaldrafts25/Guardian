/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Types of evidence that can be attached to an incident report
enum EvidenceType {
  /// Audio recording
  audio,
  
  /// Video recording
  video,
  
  /// Image
  image,
}

/// Status of an incident report
enum IncidentReportStatus {
  /// Report has been submitted but not yet reviewed
  submitted,
  
  /// Report is being reviewed by authorities
  underReview,
  
  /// Report has been verified and action is being taken
  verified,
  
  /// Report has been resolved
  resolved,
  
  /// Report has been rejected as invalid
  rejected,
}

/// A model representing an evidence file attached to an incident report
class EvidenceFile {
  /// Unique identifier for the evidence
  final String id;
  
  /// Type of evidence
  final EvidenceType type;
  
  /// URL to the file
  final String fileUrl;
  
  /// Local path to the file (if available)
  final String? localPath;
  
  /// Size of the file in bytes
  final int? fileSize;
  
  /// Duration of the recording in seconds (for audio/video)
  final int? durationSeconds;
  
  /// When the evidence was created
  final DateTime timestamp;
  
  /// Whether the evidence has been uploaded to storage
  final bool isUploaded;

  EvidenceFile({
    required this.id,
    required this.type,
    required this.fileUrl,
    this.localPath,
    this.fileSize,
    this.durationSeconds,
    required this.timestamp,
    this.isUploaded = false,
  });

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'fileUrl': fileUrl,
      'localPath': localPath,
      'fileSize': fileSize,
      'durationSeconds': durationSeconds,
      'timestamp': timestamp.toIso8601String(),
      'isUploaded': isUploaded,
    };
  }

  /// Create from a map
  factory EvidenceFile.fromMap(Map<String, dynamic> map) {
    return EvidenceFile(
      id: map['id'] ?? '',
      type: EvidenceType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => EvidenceType.image,
      ),
      fileUrl: map['fileUrl'] ?? '',
      localPath: map['localPath'],
      fileSize: map['fileSize'],
      durationSeconds: map['durationSeconds'],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isUploaded: map['isUploaded'] ?? false,
    );
  }

  /// Create a copy with updated values
  EvidenceFile copyWith({
    String? id,
    EvidenceType? type,
    String? fileUrl,
    String? localPath,
    int? fileSize,
    int? durationSeconds,
    DateTime? timestamp,
    bool? isUploaded,
  }) {
    return EvidenceFile(
      id: id ?? this.id,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      localPath: localPath ?? this.localPath,
      fileSize: fileSize ?? this.fileSize,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      timestamp: timestamp ?? this.timestamp,
      isUploaded: isUploaded ?? this.isUploaded,
    );
  }
}

/// A model representing an incident report
class IncidentReport {
  /// Unique identifier for the report
  final String id;
  
  /// ID of the user who submitted the report
  final String userId;
  
  /// Type/category of incident
  final String incidentType;
  
  /// Description of the incident
  final String description;
  
  /// Location of the incident
  final Map<String, double> location;
  
  /// Address of the incident (if available)
  final String? address;
  
  /// When the incident occurred
  final DateTime incidentTime;
  
  /// When the report was submitted
  final DateTime reportTime;
  
  /// Current status of the report
  final IncidentReportStatus status;
  
  /// Evidence files attached to the report
  final List<EvidenceFile> evidenceFiles;
  
  /// Whether the report is anonymous
  final bool isAnonymous;
  
  /// Whether the report has been shared with authorities
  final bool sharedWithAuthorities;
  
  /// Notes or additional information
  final String? notes;

  IncidentReport({
    required this.id,
    required this.userId,
    required this.incidentType,
    required this.description,
    required this.location,
    this.address,
    required this.incidentTime,
    required this.reportTime,
    required this.status,
    required this.evidenceFiles,
    required this.isAnonymous,
    required this.sharedWithAuthorities,
    this.notes,
  });

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'incidentType': incidentType,
      'description': description,
      'location': location,
      'address': address,
      'incidentTime': incidentTime.toIso8601String(),
      'reportTime': reportTime.toIso8601String(),
      'status': status.toString().split('.').last,
      'evidenceFiles': evidenceFiles.map((e) => e.toMap()).toList(),
      'isAnonymous': isAnonymous,
      'sharedWithAuthorities': sharedWithAuthorities,
      'notes': notes,
    };
  }

  /// Create from a map
  factory IncidentReport.fromMap(Map<String, dynamic> map) {
    return IncidentReport(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      incidentType: map['incidentType'] ?? '',
      description: map['description'] ?? '',
      location: Map<String, double>.from(map['location'] ?? {}),
      address: map['address'],
      incidentTime: DateTime.parse(map['incidentTime'] ?? DateTime.now().toIso8601String()),
      reportTime: DateTime.parse(map['reportTime'] ?? DateTime.now().toIso8601String()),
      status: IncidentReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => IncidentReportStatus.submitted,
      ),
      evidenceFiles: (map['evidenceFiles'] as List?)
          ?.map((e) => EvidenceFile.fromMap(e))
          .toList() ?? [],
      isAnonymous: map['isAnonymous'] ?? false,
      sharedWithAuthorities: map['sharedWithAuthorities'] ?? false,
      notes: map['notes'],
    );
  }

  /// Create a copy with updated values
  IncidentReport copyWith({
    String? id,
    String? userId,
    String? incidentType,
    String? description,
    Map<String, double>? location,
    String? address,
    DateTime? incidentTime,
    DateTime? reportTime,
    IncidentReportStatus? status,
    List<EvidenceFile>? evidenceFiles,
    bool? isAnonymous,
    bool? sharedWithAuthorities,
    String? notes,
  }) {
    return IncidentReport(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      incidentType: incidentType ?? this.incidentType,
      description: description ?? this.description,
      location: location ?? this.location,
      address: address ?? this.address,
      incidentTime: incidentTime ?? this.incidentTime,
      reportTime: reportTime ?? this.reportTime,
      status: status ?? this.status,
      evidenceFiles: evidenceFiles ?? this.evidenceFiles,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      sharedWithAuthorities: sharedWithAuthorities ?? this.sharedWithAuthorities,
      notes: notes ?? this.notes,
    );
  }
}
