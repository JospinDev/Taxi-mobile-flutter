import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/notifications/data/notification_model.dart';
import 'package:my_app/features/payments/data/wallet_model.dart';
import 'package:my_app/features/rides/data/models/ride_model.dart';

void main() {
  test('Ride.fromJson parses the backend payload', () {
    final ride = Ride.fromJson({
      'id': 7,
      'status': 'in_progress',
      'client': {'id': 1, 'name': 'Alice', 'phone': '+25779000001'},
      'driver': {'id': 2, 'name': 'Jean', 'phone': '+25777000001', 'rating': '4.50', 'location': {'lat': -3.38, 'lng': 29.36}},
      'vehicle': {'id': 3, 'plate_number': 'B1234A', 'brand': 'Toyota', 'model': 'Corolla', 'color': 'Blanc'},
      'pickup': {'lat': -3.3822, 'lng': 29.3644},
      'dropoff': {'lat': -3.37, 'lng': 29.36},
      'estimated_fare': '2300.00',
      'live_distance_km': 1.234,
      'payment_method': 'mobile_money',
      'requested_at': '2026-11-09T10:00:00Z',
    });
    expect(ride.status, RideStatus.inProgress);
    expect(ride.status.isActive, isTrue);
    expect(ride.driverLocation!.lat, -3.38);
    expect(ride.vehicle!.plate, 'B1234A');
    expect(ride.paymentMethod, PaymentMethod.mobileMoney);
    expect(ride.estimatedFare, 2300);
    expect(ride.displayFare, 2300);
    expect(ride.status.clientCanCancel, isFalse);
  });

  test('live update moves the driver but keeps the rest', () {
    final ride = Ride.fromJson({
      'id': 1, 'status': 'accepted',
      'driver': {'id': 2, 'name': 'Jean'},
      'pickup': {'lat': 0.0, 'lng': 0.0}, 'dropoff': {'lat': 1.0, 'lng': 1.0},
    });
    final moved = ride.withLive(driverLocation: ride.pickup, distanceKm: 2.5);
    expect(moved.driver!.name, 'Jean');
    expect(moved.driverLocation, ride.pickup);
    expect(moved.liveDistanceKm, 2.5);
  });

  test('RideOffer from websocket event has a countdown', () {
    final o = RideOffer.fromEvent({
      'ride_id': 9, 'estimated_fare': '2500.00', 'distance_to_pickup_m': 800,
      'pickup': {'lat': 1.0, 'lng': 2.0}, 'dropoff': {'lat': 3.0, 'lng': 4.0}, 'expires_in_s': 20,
    });
    expect(o.rideId, 9);
    expect(o.remaining.inSeconds, inInclusiveRange(18, 20));
    expect(o.isExpired, isFalse);
  });

  test('AppNotification reads popup config', () {
    final n = AppNotification.fromJson({
      'id': 5, 'event': 'ride_offer', 'title': 'T', 'body': 'B', 'ride_id': 3,
      'popup': {'ttl_s': 20, 'priority': 'high'},
    });
    expect(n.highPriority, isTrue);
    expect(n.popupTtl.inSeconds, 20);
    expect(n.rideId, 3);
  });

  test('Wallet debt is detected', () {
    final w = Wallet.fromJson({'id': 1, 'driver': 2, 'driver_name': 'Jean', 'balance': '-460.00'});
    expect(w.inDebt, isTrue);
    final tx = WalletTransaction.fromJson({'id': 1, 'type': 'commission', 'amount': '-460.00', 'balance_after': '-460.00'});
    expect(tx.isCredit, isFalse);
    expect(tx.type, WalletTxType.commission);
  });
}
