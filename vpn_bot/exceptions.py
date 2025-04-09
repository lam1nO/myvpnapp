class CreatePaymentError(Exception):
    """Create payment error"""
    def __init__(self, message='Unknown Error'):
        super().__init__(message)