package SMS::Send::KR::APIStore;
# ABSTRACT: An SMS::Send driver for the apistore.co.kr SMS service

use utf8;
use strict;
use warnings;

our $VERSION = '0.001';

use parent qw( SMS::Send::Driver );

use HTTP::Tiny;
use JSON;

our $URL     = "http://api.openapi.io/ppurio/1/message";
our $AGENT   = 'SMS-Send-KR-APIStore/' . $SMS::Send::KR::APIStore::VERSION;
our $TIMEOUT = 3;
our $TYPE    = 'SMS';
our $DELAY   = 0;

our %ERROR_CODE = (
    '4100' => 'sms:전달',
    '4421' => 'sms:타임아웃',
    '4426' => 'sms:재시도한도초과',
    '4425' => 'sms:단말기호처리중',
    '4400' => 'sms:음영지역',
    '4401' => 'sms:단말기전원꺼짐',
    '4402' => 'sms:단말기메시지저장초과',
    '4410' => 'sms:잘못된번호',
    '4422' => 'sms:단말기일시정지',
    '4427' => 'sms:기타단말기문제',
    '4405' => 'sms:단말기 busy',
    '4423' => 'sms:단말기착신거부',
    '4412' => 'sms:착신거절',
    '4411' => 'sms:NPDB 에러',
    '4428' => 'sms:시스템에러',
    '4404' => 'sms:가입자위치정보없음',
    '4413' => 'sms:SMSC 형식오류',
    '4414' => 'sms:비가입자,결번,서비스정지',
    '4424' => 'sms:URL SMS 미지원폰',
    '4403' => 'sms:메시지삭제됨',
    '4430' => 'sms:스팸',
    '4420' => 'sms:기타에러',
    '6600' => 'mms:전달',
    '6601' => 'mms:타임아웃',
    '6602' => 'mms:핸드폰호처리중',
    '6603' => 'mms:음영지역',
    '6604' => 'mms:전원이꺼져있음',
    '6605' => 'mms:메시지저장개수초과',
    '6606' => 'mms:잘못된번호',
    '6607' => 'mms:서비스일시정지',
    '6608' => 'mms:기타단말기문제',
    '6609' => 'mms:착신거절',
    '6610' => 'mms:기타에러',
    '6611' => 'mms:통신사의 SMC 형식오류',
    '6612' => 'mms:게이트웨이의형식오류',
    '6613' => 'mms:서비스불가단말기',
    '6614' => 'mms:핸드폰호불가상태',
    '6615' => 'mms:SMC 운영자에의해삭제',
    '6616' => 'mms:통신사의메시지큐초과',
    '6617' => 'mms:통신사의스팸처리',
    '6618' => 'mms:공정위의스팸처리',
    '6619' => 'mms:게이트웨이의스팸처리',
    '6620' => 'mms:발송건수초과',
    '6621' => 'mms:메시지의길이초과',
    '6622' => 'mms:잘못된번호형식',
    '6623' => 'mms:잘못된데이터형식',
    '6624' => 'mms:MMS 정보를찾을수없음',
    '6670' => 'mms:이미지파일크기제한',
    '9903' => '선불사용자 사용금지',
    '9904' => 'Block time(날짜제한)',
    '9082' => '발송해제',
    '9083' => 'IP 차단',
    '9023' => 'Callback error',
    '9905' => 'Block time(요일제한)',
    '9010' => '아이디 틀림',
    '9011' => '비밀번호 틀림',
    '9012' => '중복접속량 많음',
    '9013' => '발송시간 지난 데이터',
    '9014' => '시간제한(리포트 수신대기 timeout)',
    '9020' => 'Wrong Data Format',
    '9021' => '',
    '9022' => 'Wrong Data Format(cinfo가 특수 문자/공백을 포함)',
    '9080' => 'Deny User Ack',
    '9214' => 'Wrong Phone Num',
    '9311' => 'Fax File Not Found',
    '9908' => 'PHONE, FAX 선불사용자 제한기능',
    '9090' => '기타에러',
    '-1'   => '잘못된 데이터 형식 발송오류',
);

sub new {
    my $class  = shift;
    my %params = (
        _url           => $SMS::Send::KR::APIStore::URL,
        _agent         => $SMS::Send::KR::APIStore::AGENT,
        _timeout       => $SMS::Send::KR::APIStore::TIMEOUT,
        _from          => q{},
        _type          => $SMS::Send::KR::APIStore::TYPE,
        _delay         => $SMS::Send::KR::APIStore::DELAY,
        _id            => q{},
        _api_store_key => q{},
        @_,
    );

    die "$class->new: _id is needed\n"            unless $params{_id};
    die "$class->new: _api_store_key is needed\n" unless $params{_api_store_key};
    die "$class->new: _from is needed\n"          unless $params{_from};
    die "$class->new: _type is invalid\n"
        unless $params{_type} && $params{_type} =~ m/^(SMS|LMS)$/i;

    my $self = bless \%params, $class;
    return $self;
}

sub send_sms {
    my $self   = shift;
    my %params = (
        _from    => $self->{_from},
        _type    => $self->{_type} || 'SMS',
        _delay   => $self->{_delay} || 0,
        _subject => $self->{_subject},
        _epoch   => q{},
        @_,
    );

    my $text    = $params{text};
    my $to      = $params{to};
    my $from    = $params{_from};
    my $type    = $params{_type};
    my $delay   = $params{_delay};
    my $subject = $params{_subject};
    my $epoch   = $params{_epoch};

    my %ret = (
        success => 0,
        reason  => q{},
        detail  => +{},
    );

    $ret{reason} = 'text is needed', return \%ret unless $text;
    $ret{reason} = 'to is needed',   return \%ret unless $to;
    $ret{reason} = '_type is invalid', return \%ret
        unless $type && $type =~ m/^(SMS|LMS)$/i;

    my $http = HTTP::Tiny->new(
        agent           => $self->{_agent},
        timeout         => $self->{_timeout},
        default_headers => { 'x-waple-authorization' => $self->{_api_store_key} },
    ) or $ret{reason} = 'cannot generate HTTP::Tiny object', return \%ret;
    my $url = sprintf '%s/%s/%s', $self->{_url}, lc($type), $self->{_id};

    #
    # delay / send_time: reserve SMS
    #
    my $send_time;
    if ($delay) {
        my $t = DateTime->now( time_zone => 'Asia/Seoul' )->add( seconds => $delay );
        $send_time = $t->ymd(q{}) . $t->hms(q{});
    }
    if ($epoch) {
        my $t = DateTime->from_epoch(
            time_zone => 'Asia/Seoul',
            epoch     => $epoch,
        );
        $send_time = $t->ymd(q{}) . $t->hms(q{});
    }

    #
    # subject
    #
    undef $subject if $type =~ m/SMS/i;

    my %form = (
        dest_phone => $to,
        send_phone => $from,
        subject    => $subject,
        msg_body   => $text,
        send_time  => $send_time,
    );
    $form{$_} or delete $form{$_} for keys %form;

    my $res = $http->post_form( $url, \%form );
    $ret{reason} = 'cannot get valid response for POST request';
    if ( $res && $res->{success} ) {
        $ret{detail} = decode_json( $res->{content} );
        $ret{success} = 1 if $ret{detail}{result_code} eq '200';

        $ret{reason} = 'unknown error';
        $ret{reason} = 'user error' if $ret{detail}{result_code} eq '100';
        $ret{reason} = 'ok' if $ret{detail}{result_code} eq '200';
        $ret{reason} = 'parameter error' if $ret{detail}{result_code} eq '300';
        $ret{reason} = 'etc error' if $ret{detail}{result_code} eq '400';
    }
    else {
        $ret{detail} = $res;
        $ret{reason} = 'unknown error';
    }

    return \%ret;
}

sub report {
    my ( $self, $cmid_obj ) = @_;

    my %ret = (
        success     => 0,
        reason      => q{},
        cmid        => q{},
        call_status => q{},
        dest_phone  => q{},
        report_time => q{},
        umid        => q{},
    );

    $ret{reason} = 'cmid is needed', return \%ret unless defined $cmid_obj;

    my $cmid;
    if ( !ref($cmid_obj) ) {
        $cmid = $cmid_obj;
    }
    elsif ( ref($cmid_obj) eq 'HASH' ) {
        $cmid = $cmid_obj->{detail}{cmid};
    }
    else {
        $ret{reason} = 'invalid cmid';
        return \%ret;
    }
    $ret{cmid} = $cmid;

    my $http = HTTP::Tiny->new(
        agent           => $self->{_agent},
        timeout         => $self->{_timeout},
        default_headers => { 'x-waple-authorization' => $self->{_api_store_key} },
    ) or $ret{reason} = 'cannot generate HTTP::Tiny object', return \%ret;
    my $url = sprintf '%s/%s/%s', $self->{_url}, 'report', $self->{_id};

    my %form = ( cmid => $cmid );
    $form{$_} or delete $form{$_} for keys %form;
    my $params = $http->www_form_urlencode( \%form );

    my $res = $http->get("$url?$params");
    $ret{reason} = 'cannot get valid response for GET request';
    if ( $res && $res->{success} ) {
        my $detail = decode_json( $res->{content} );

        $ret{success}     = 1 if $detail->{call_status} =~ m/^(4100|6600)$/;
        $ret{reason}      = $ERROR_CODE{ $detail->{call_status} };
        $ret{call_status} = $detail->{call_status};
        $ret{dest_phone}  = $detail->{dest_phone};
        $ret{report_time} = $detail->{report_time};
        $ret{umid}        = $detail->{umid};
    }
    else {
        $ret{detail} = $res;
        $ret{reason} = 'unknown error';
    }

    return \%ret;
}

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    use SMS::Send;

    # create the sender object
    my $sender = SMS::Send->new('KR::APIStore',
        _id            => 'keedi',
        _api_store_key => 'XXXXXXXX',
        _from          => '01025116893',
    );

    # send a message
    my $sent = $sender->send_sms(
        text  => 'You message may use up to 80 chars and must be utf8',
        to    => '01012345678',
    );

    unless ( $sent->{success} ) {
        warn "failed to send sms: $sent->{reason}\n";

        # if you want to know detail more, check $sent->{detail}
        use Data::Dumper;
        warn Dumper $sent->{detail};
    }

    # Of course you can send LMS
    my $sender = SMS::Send->new('KR::APIStore',
        _id            => 'keedi',
        _api_store_key => 'XXXXXXXX',
        _type          => 'lms',
        _from          => '01025116893',
    );

    # You can override _from or _type

    # send a message
    my $sent = $sender->send_sms(
        text     => 'You LMS message may use up to 2000 chars and must be utf8',
        to       => '01025116893',
        _from    => '02114',             # you can override $self->_from
        _type    => 'LMS',               # you can override $self->_type
        _subject => 'This is a subject', # subject is optional & up to 40 chars
    );

    # check the result
    my $result = $sender->report("20130314163439459");
    printf "success:     %s\n", $result->{success} ? 'success' : 'fail';
    printf "reason:      %s\n", $result->{reason};
    printf "call_status: %s\n", $result->{call_status};
    printf "dest_phone:  %s\n", $result->{dest_phone};
    printf "report_time: %s\n", $result->{report_time};
    printf "cmid:        %s\n", $result->{cmid};
    printf "umid:        %s\n", $result->{umid};

    # you can use cmid of the send_sms() result
    my $sent = $sender->send_sms( ... );
    my $result = $sender->report( $sent->{detail}{cmid} );

    # or you can use the send_sms() result itself
    my $sent = $sender->send_sms( ... );
    my $result = $sender->report($sent);


=head1 DESCRIPTION

...
