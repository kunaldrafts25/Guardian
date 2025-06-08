/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';

/// Repository for handling NGO integration functionality
class NGORepository {
  static const String _ngosCollection = 'ngos';
  static const String _servicesCollection = 'ngo_services';
  static const String _bookingsCollection = 'service_bookings';
  static const String _donationsCollection = 'donations';
  static const String _volunteersCollection = 'volunteers';
  
  /// Get all NGOs
  Future<List<NGO>> getNGOs() async {
    try {
      final ngosData = await MockDataService.getCollection(_ngosCollection);
      
      return ngosData.map((ngo) => NGO.fromMap(ngo)).toList();
    } catch (e) {
      Logger.error('Failed to get NGOs', e);
      return [];
    }
  }
  
  /// Get NGOs by type
  Future<List<NGO>> getNGOsByType(NGOType type) async {
    try {
      final ngos = await getNGOs();
      
      return ngos.where((ngo) => ngo.type == type).toList();
    } catch (e) {
      Logger.error('Failed to get NGOs by type', e);
      return [];
    }
  }
  
  /// Get NGO by ID
  Future<NGO?> getNGOById(String id) async {
    try {
      final ngoData = await MockDataService.getDocument(_ngosCollection, id);
      
      if (ngoData == null) {
        return null;
      }
      
      return NGO.fromMap(ngoData);
    } catch (e) {
      Logger.error('Failed to get NGO by ID', e);
      return null;
    }
  }
  
  /// Search NGOs by query
  Future<List<NGO>> searchNGOs(String query) async {
    try {
      final ngos = await getNGOs();
      
      if (query.isEmpty) {
        return ngos;
      }
      
      final lowercaseQuery = query.toLowerCase();
      
      return ngos.where((ngo) {
        return ngo.name.toLowerCase().contains(lowercaseQuery) ||
            ngo.description.toLowerCase().contains(lowercaseQuery) ||
            ngo.services.any((service) => 
                service.name.toLowerCase().contains(lowercaseQuery) ||
                service.description.toLowerCase().contains(lowercaseQuery));
      }).toList();
    } catch (e) {
      Logger.error('Failed to search NGOs', e);
      return [];
    }
  }
  
  /// Get all services
  Future<List<NGOService>> getAllServices() async {
    try {
      final servicesData = await MockDataService.getCollection(_servicesCollection);
      
      return servicesData.map((service) => NGOService.fromMap(service)).toList();
    } catch (e) {
      Logger.error('Failed to get all services', e);
      return [];
    }
  }
  
  /// Get services by type
  Future<List<NGOService>> getServicesByType(String type) async {
    try {
      final services = await getAllServices();
      
      return services.where((service) => service.type == type).toList();
    } catch (e) {
      Logger.error('Failed to get services by type', e);
      return [];
    }
  }
  
  /// Get service by ID
  Future<NGOService?> getServiceById(String id) async {
    try {
      final serviceData = await MockDataService.getDocument(_servicesCollection, id);
      
      if (serviceData == null) {
        return null;
      }
      
      return NGOService.fromMap(serviceData);
    } catch (e) {
      Logger.error('Failed to get service by ID', e);
      return null;
    }
  }
  
  /// Book a service
  Future<String?> bookService({
    required String serviceId,
    required String ngoId,
    required DateTime appointmentDate,
    String? notes,
  }) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Get service details
      final service = await getServiceById(serviceId);
      if (service == null) {
        throw Exception('Service not found');
      }
      
      // Create booking
      final booking = {
        'userId': user.uid,
        'serviceId': serviceId,
        'ngoId': ngoId,
        'appointmentDate': appointmentDate.toIso8601String(),
        'notes': notes,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Save booking
      final bookingId = await MockDataService.addDocument(
        _bookingsCollection,
        booking,
      );
      
      return bookingId;
    } catch (e) {
      Logger.error('Failed to book service', e);
      return null;
    }
  }
  
  /// Get user's bookings
  Future<List<Map<String, dynamic>>> getUserBookings() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final bookingsData = await MockDataService.getCollection(_bookingsCollection);
      
      final userBookings = bookingsData
          .where((booking) => booking['userId'] == user.uid)
          .toList();
      
      // Enrich bookings with service and NGO details
      final enrichedBookings = <Map<String, dynamic>>[];
      
      for (final booking in userBookings) {
        final serviceId = booking['serviceId'] as String;
        final ngoId = booking['ngoId'] as String;
        
        final service = await getServiceById(serviceId);
        final ngo = await getNGOById(ngoId);
        
        if (service != null && ngo != null) {
          enrichedBookings.add({
            ...booking,
            'service': service.toMap(),
            'ngo': ngo.toMap(),
          });
        }
      }
      
      return enrichedBookings;
    } catch (e) {
      Logger.error('Failed to get user bookings', e);
      return [];
    }
  }
  
  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final bookingData = await MockDataService.getDocument(_bookingsCollection, bookingId);
      
      if (bookingData == null) {
        return false;
      }
      
      // Update booking status
      final updatedBooking = {
        ...bookingData,
        'status': 'cancelled',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      return await MockDataService.updateDocument(
        _bookingsCollection,
        bookingId,
        updatedBooking,
      );
    } catch (e) {
      Logger.error('Failed to cancel booking', e);
      return false;
    }
  }
  
  /// Make a donation to an NGO
  Future<String?> makeDonation({
    required String ngoId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? message,
  }) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Get NGO details
      final ngo = await getNGOById(ngoId);
      if (ngo == null) {
        throw Exception('NGO not found');
      }
      
      if (!ngo.acceptsDonations) {
        throw Exception('NGO does not accept donations');
      }
      
      // Create donation
      final donation = {
        'userId': user.uid,
        'ngoId': ngoId,
        'amount': amount,
        'currency': currency,
        'paymentMethod': paymentMethod,
        'message': message,
        'status': 'completed',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Save donation
      final donationId = await MockDataService.addDocument(
        _donationsCollection,
        donation,
      );
      
      return donationId;
    } catch (e) {
      Logger.error('Failed to make donation', e);
      return null;
    }
  }
  
  /// Get user's donations
  Future<List<Map<String, dynamic>>> getUserDonations() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final donationsData = await MockDataService.getCollection(_donationsCollection);
      
      final userDonations = donationsData
          .where((donation) => donation['userId'] == user.uid)
          .toList();
      
      // Enrich donations with NGO details
      final enrichedDonations = <Map<String, dynamic>>[];
      
      for (final donation in userDonations) {
        final ngoId = donation['ngoId'] as String;
        
        final ngo = await getNGOById(ngoId);
        
        if (ngo != null) {
          enrichedDonations.add({
            ...donation,
            'ngo': ngo.toMap(),
          });
        }
      }
      
      return enrichedDonations;
    } catch (e) {
      Logger.error('Failed to get user donations', e);
      return [];
    }
  }
  
  /// Register as a volunteer
  Future<String?> registerAsVolunteer({
    required String ngoId,
    required String name,
    required String email,
    required String phone,
    required List<String> interests,
    required String availability,
    String? message,
  }) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Get NGO details
      final ngo = await getNGOById(ngoId);
      if (ngo == null) {
        throw Exception('NGO not found');
      }
      
      if (!ngo.acceptsVolunteers) {
        throw Exception('NGO does not accept volunteers');
      }
      
      // Create volunteer registration
      final volunteer = {
        'userId': user.uid,
        'ngoId': ngoId,
        'name': name,
        'email': email,
        'phone': phone,
        'interests': interests,
        'availability': availability,
        'message': message,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Save volunteer registration
      final volunteerId = await MockDataService.addDocument(
        _volunteersCollection,
        volunteer,
      );
      
      return volunteerId;
    } catch (e) {
      Logger.error('Failed to register as volunteer', e);
      return null;
    }
  }
  
  /// Get user's volunteer registrations
  Future<List<Map<String, dynamic>>> getUserVolunteerRegistrations() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final volunteersData = await MockDataService.getCollection(_volunteersCollection);
      
      final userVolunteers = volunteersData
          .where((volunteer) => volunteer['userId'] == user.uid)
          .toList();
      
      // Enrich volunteer registrations with NGO details
      final enrichedVolunteers = <Map<String, dynamic>>[];
      
      for (final volunteer in userVolunteers) {
        final ngoId = volunteer['ngoId'] as String;
        
        final ngo = await getNGOById(ngoId);
        
        if (ngo != null) {
          enrichedVolunteers.add({
            ...volunteer,
            'ngo': ngo.toMap(),
          });
        }
      }
      
      return enrichedVolunteers;
    } catch (e) {
      Logger.error('Failed to get user volunteer registrations', e);
      return [];
    }
  }
}
