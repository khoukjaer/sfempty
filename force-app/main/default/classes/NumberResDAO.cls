public with sharing class NumberResDAO {

    public class NumberDetail {

        public NumberData data;

        public Error error;

    }

 

    public class NumberDetails {

        public List<NumberData> data;

        public Integer pageSize;

        public Error error;

    }

 

    public class NumberData {

        public String countryCode;

        public String id;

        public String phoneNumber; //actual reponse has "number", which is a recerved keyword so we replace before deserialization

        public String numberGroup;

        public String numberLocation;

        public String numberStatus;

        public List<String> productType;

    }

 

    public class PortOrders {

        public List<PortOrderData> data;

        public Error error;

    }

 

    public class PortOrderData {

        public Integer currentStatusCode;

        public String externalStatusCode;

        public String iccNumber;

        public String msisdn;

        public String ochNumber;

        public String orderId;

        public String portingCase;

        public Datetime requestExecutionDate;

        public String subStatusCode;

        public String transactionStatusCode;

    }

 

    public class Error {

        public Integer code;

        public String message;

        public List<ErrorParameter> parameters;

    }

 

    public class ErrorParameter {

        public String key;

        public String value;

    }

}
