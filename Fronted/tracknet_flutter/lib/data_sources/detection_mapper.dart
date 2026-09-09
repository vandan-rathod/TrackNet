import '../models/domain.dart';
import '../models/plate.dart';
import 'backend_transport.dart';

class DetectionMapper implements DtoMapper<DetectionInput, Detection> {
  const DetectionMapper();
  @override
  Detection toDomain(DetectionInput dto) {
    if (dto.confidence != null &&
        (dto.confidence! < 0 || dto.confidence! > 100)) {
      throw const FormatException(
        'Confidence must be a percentage in [0, 100]',
      );
    }
    final unreadable =
        dto.status == DetectionStatus.noPlateDetected ||
        dto.status == DetectionStatus.lowConfidenceUnreadable;
    final plate = unreadable ? null : dto.acceptedPlate;
    if (plate != null && !PlateRecognition.valid(plate)) {
      throw const FormatException('Invalid accepted plate');
    }
    return Detection(
      id: dto.id,
      cameraId: dto.cameraId,
      timestamp: dto.timestamp,
      status: dto.status,
      context: dto.context,
      rawOcr: dto.rawOcr,
      plate: plate == null ? null : PlateRecognition.normalize(plate),
      confidence: dto.confidence,
      speed: dto.speed,
      vehicleType: dto.vehicleType,
    );
  }
}
