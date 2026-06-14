import logging
import re


class SensitiveDataFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            record.msg = re.sub(r"[A-Za-z0-9+/]{100,}", "[ENCRYPTED_DATA]", record.msg)
            record.msg = re.sub(r"Bearer\s+[A-Za-z0-9\-_\.]+", "Bearer [TOKEN]", record.msg)
        if isinstance(record.args, dict):
            record.args = {
                k: "[ENCRYPTED_DATA]" if isinstance(v, str) and len(v) > 100 else v
                for k, v in record.args.items()
            }
        return True


def setup_logging(level: str = "INFO") -> logging.Logger:
    logger = logging.getLogger("darsak")
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.addFilter(SensitiveDataFilter())
        formatter = logging.Formatter(
            "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    return logger
