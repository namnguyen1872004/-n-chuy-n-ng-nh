import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:dat_ve_xem_phim/firebase_options.dart';

// Screens
import 'Screen/home_screen.dart';
import 'Screen/login_screen.dart';
import 'services/auth_service.dart';
import 'Screen/profile_screen.dart';
import 'Screen/edit_profile_screen.dart';
import 'Screen/cinema_screen.dart';
import 'Screen/snack_screen.dart';
import 'Screen/movie_detail_screen.dart';
import 'Screen/booking_screen.dart';
import 'Screen/seat_selection_screen.dart';
import 'Screen/movie_selection_screen.dart';
import 'Screen/showtimes_screen.dart';

// Models
import 'models/movie.dart';
import 'models/cinema_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đặt Vé Xem Phim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/login',
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          // ===== Static =====
          case '/login':
            return _mat(LoginScreen(authService: AuthService()));
          case '/home':
            return _mat(const HomeScreen());
          case '/profile':
            return _mat(const ProfileScreen());
          case '/edit-profile':
            return _mat(const EditProfileScreen());
          case '/cinema':
            return _mat(const CinemaScreen());
          case '/snack':
            return _mat(const SnackScreen());

          // ===== Dynamic =====

          case '/details':
            {
              final args = settings.arguments;
              if (args is Movie) return _mat(MovieDetailScreen(movie: args));
              return _err('Lỗi: /details cần Movie.');
            }

          case '/movie-selection':
            {
              final args = settings.arguments;
              Cinema? cinema;
              if (args is Cinema) cinema = args;
              if (args is Map && args['cinema'] is Cinema) {
                cinema = args['cinema'] as Cinema;
              }
              if (cinema != null) {
                return _mat(MovieSelectionScreen(cinema: cinema));
              }
              return _err('Lỗi: /movie-selection cần Cinema.');
            }

          case '/showtimes':
            {
              final args = settings.arguments;
              if (args is Map &&
                  args['selectedCinema'] is Cinema &&
                  args['selectedMovie'] is Movie &&
                  args['selectedDate'] is DateTime) {
                return _mat(
                  ShowtimesScreen(
                    selectedCinema: args['selectedCinema'] as Cinema,
                    selectedMovie: args['selectedMovie'] as Movie,
                    selectedDate: args['selectedDate'] as DateTime,
                    selectedTime: args['selectedTime'] as TimeOfDay?,
                  ),
                );
              }
              return _err(
                'Lỗi: /showtimes cần {selectedCinema, selectedMovie, selectedDate, selectedTime?}.',
              );
            }

          case '/booking':
            {
              final args = settings.arguments;
              Movie? movie;
              if (args is Movie) movie = args;
              if (args is Map && args['movie'] is Movie) {
                movie = args['movie'] as Movie;
              }
              if (movie != null) {
                return _mat(BookingScreen(movie: movie));
              }
              return _err('Lỗi: /booking cần Movie.');
            }

          case '/seat-selection':
            {
              final args = settings.arguments;
              if (args is Map &&
                  args['movie'] is Movie &&
                  args['selectedDate'] is DateTime &&
                  args['selectedCinema'] is String &&
                  args['selectedTime'] is TimeOfDay) {
                return _mat(
                  SeatSelectionScreen(
                    movie: args['movie'] as Movie,
                    selectedDate: args['selectedDate'] as DateTime,
                    selectedCinema: args['selectedCinema'] as String,
                    selectedTime: args['selectedTime'] as TimeOfDay,
                  ),
                );
              }
              return _err(
                'Lỗi: /seat-selection cần {movie, selectedDate, selectedCinema(String), selectedTime}.',
              );
            }

          default:
            return _err('Route không tồn tại: ${settings.name}');
        }
      },
    );
  }

  static MaterialPageRoute _mat(Widget child) =>
      MaterialPageRoute(builder: (_) => child);

  static MaterialPageRoute _err(String msg) => _mat(
    Scaffold(
      body: Center(
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    ),
  );
}
