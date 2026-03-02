"""
이메일 발송 서비스
비밀번호 변경 인증 이메일 발송을 위한 유틸리티
작성일: 2026-01-15
작성자: 김택권
"""

import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional


class EmailService:
    """이메일 발송 서비스 클래스"""
    
    # SMTP 설정 (환경변수 또는 설정 파일에서 읽어올 수 있음)
    SMTP_HOST = os.getenv('SMTP_HOST', 'smtp.gmail.com')
    SMTP_PORT = int(os.getenv('SMTP_PORT', '587'))
    SMTP_USER = os.getenv('SMTP_USER', '')  # 발신자 이메일
    SMTP_PASSWORD = os.getenv('SMTP_PASSWORD', '')  # 발신자 비밀번호 또는 앱 비밀번호
    FROM_NAME = os.getenv('FROM_NAME', 'HabitCell')
    
    @classmethod
    def get_from_email(cls) -> str:
        """
        발신자 이메일 주소 반환
        Gmail 사용 시 SMTP_USER와 일치해야 하므로 자동으로 설정
        """
        from_email = os.getenv('FROM_EMAIL', '')
        # Gmail 사용 시 또는 FROM_EMAIL이 설정되지 않은 경우 SMTP_USER 사용
        if not from_email or 'gmail.com' in cls.SMTP_HOST.lower():
            return cls.SMTP_USER if cls.SMTP_USER else 'noreply@habitcell.com'
        return from_email
    
    @classmethod
    def send_password_reset_email(
        cls,
        to_email: str,
        customer_name: str,
        auth_code: str,
        expires_minutes: int = 10
    ) -> bool:
        """
        비밀번호 변경 인증 이메일 발송
        
        Args:
            to_email: 수신자 이메일
            customer_name: 고객 이름
            auth_code: 인증 코드 (6자리 숫자)
            expires_minutes: 만료 시간 (분)
            
        Returns:
            bool: 발송 성공 여부
        """
        try:
            # 이메일 내용 작성
            subject = '[HabitCell] 비밀번호 변경 인증 코드'
            
            html_content = f"""
            <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: #212121;">비밀번호 변경 인증</h2>
                    <p>안녕하세요, {customer_name}님.</p>
                    <p>비밀번호 변경을 위한 인증 코드입니다.</p>
                    <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                        <h1 style="color: #212121; margin: 0; font-size: 32px; letter-spacing: 5px;">{auth_code}</h1>
                    </div>
                    <p>이 코드는 <strong>{expires_minutes}분</strong> 동안 유효합니다.</p>
                    <p style="color: #757575; font-size: 12px;">본인이 요청한 것이 아니라면 이 이메일을 무시하세요.</p>
                </div>
            </body>
            </html>
            """
            
            text_content = f"""
            비밀번호 변경 인증
            
            안녕하세요, {customer_name}님.
            
            비밀번호 변경을 위한 인증 코드입니다.
            
            인증 코드: {auth_code}
            
            이 코드는 {expires_minutes}분 동안 유효합니다.
            
            본인이 요청한 것이 아니라면 이 이메일을 무시하세요.
            """
            
            # 이메일 메시지 생성
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = f"{cls.FROM_NAME} <{cls.get_from_email()}>"
            msg['To'] = to_email
            
            # 텍스트 및 HTML 내용 추가
            part1 = MIMEText(text_content, 'plain', 'utf-8')
            part2 = MIMEText(html_content, 'html', 'utf-8')
            msg.attach(part1)
            msg.attach(part2)
            
            # SMTP 서버 연결 및 이메일 발송
            with smtplib.SMTP(cls.SMTP_HOST, cls.SMTP_PORT) as server:
                server.starttls()
                if cls.SMTP_USER and cls.SMTP_PASSWORD:
                    server.login(cls.SMTP_USER, cls.SMTP_PASSWORD)
                server.send_message(msg)
            
            return True
            
        except Exception as e:
            print(f"이메일 발송 실패: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    @classmethod
    def send_password_reset_link(
        cls,
        to_email: str,
        customer_name: str,
        reset_link: str,
        expires_minutes: int = 10
    ) -> bool:
        """
        비밀번호 변경 링크 이메일 발송 (대안 방법)
        
        Args:
            to_email: 수신자 이메일
            customer_name: 고객 이름
            reset_link: 비밀번호 변경 링크
            expires_minutes: 만료 시간 (분)
            
        Returns:
            bool: 발송 성공 여부
        """
        try:
            subject = '[HabitCell] 비밀번호 변경 링크'
            
            html_content = f"""
            <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: #212121;">비밀번호 변경</h2>
                    <p>안녕하세요, {customer_name}님.</p>
                    <p>비밀번호 변경을 위해 아래 링크를 클릭해주세요.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{reset_link}" 
                           style="background-color: #212121; color: white; padding: 12px 30px; 
                                  text-decoration: none; border-radius: 5px; display: inline-block;">
                            비밀번호 변경하기
                        </a>
                    </div>
                    <p>이 링크는 <strong>{expires_minutes}분</strong> 동안 유효합니다.</p>
                    <p style="color: #757575; font-size: 12px;">본인이 요청한 것이 아니라면 이 이메일을 무시하세요.</p>
                </div>
            </body>
            </html>
            """
            
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = f"{cls.FROM_NAME} <{cls.get_from_email()}>"
            msg['To'] = to_email
            
            part = MIMEText(html_content, 'html', 'utf-8')
            msg.attach(part)
            
            with smtplib.SMTP(cls.SMTP_HOST, cls.SMTP_PORT) as server:
                server.starttls()
                if cls.SMTP_USER and cls.SMTP_PASSWORD:
                    server.login(cls.SMTP_USER, cls.SMTP_PASSWORD)
                server.send_message(msg)
            
            return True
            
        except Exception as e:
            print(f"이메일 발송 실패: {e}")
            import traceback
            traceback.print_exc()
            return False

    @classmethod
    def send_verification_code(
        cls,
        to_email: str,
        code: str,
        expires_minutes: int = 10
    ) -> bool:
        """
        Habit App 복구용 6자리 인증 코드 이메일 발송

        Args:
            to_email: 수신자 이메일
            code: 6자리 인증 코드
            expires_minutes: 만료 시간 (분)

        Returns:
            bool: 발송 성공 여부
        """
        try:
            subject = '[HabitCell] 백업 복구 인증 코드'

            html_content = f"""
            <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: #212121;">백업 복구 인증</h2>
                    <p>HabitCell 백업 복구를 위한 인증 코드입니다.</p>
                    <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                        <h1 style="color: #212121; margin: 0; font-size: 32px; letter-spacing: 5px;">{code}</h1>
                    </div>
                    <p>이 코드는 <strong>{expires_minutes}분</strong> 동안 유효합니다.</p>
                    <p style="color: #757575; font-size: 12px;">본인이 요청한 것이 아니라면 이 이메일을 무시하세요.</p>
                </div>
            </body>
            </html>
            """

            text_content = f"""
            백업 복구 인증

            HabitCell 백업 복구를 위한 인증 코드입니다.

            인증 코드: {code}

            이 코드는 {expires_minutes}분 동안 유효합니다.

            본인이 요청한 것이 아니라면 이 이메일을 무시하세요.
            """

            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = f"{cls.FROM_NAME} <{cls.get_from_email()}>"
            msg['To'] = to_email

            part1 = MIMEText(text_content, 'plain', 'utf-8')
            part2 = MIMEText(html_content, 'html', 'utf-8')
            msg.attach(part1)
            msg.attach(part2)

            with smtplib.SMTP(cls.SMTP_HOST, cls.SMTP_PORT) as server:
                server.starttls()
                if cls.SMTP_USER and cls.SMTP_PASSWORD:
                    server.login(cls.SMTP_USER, cls.SMTP_PASSWORD)
                server.send_message(msg)

            return True

        except Exception as e:
            print(f"이메일 발송 실패: {e}")
            import traceback
            traceback.print_exc()
            return False


# ============================================================
# 생성 이력
# ============================================================
# 작성일: 2026-01-15
# 작성자: 김택권
# 설명: 이메일 발송 서비스 - 비밀번호 변경 인증 이메일 발송을 위한 유틸리티
#
# ============================================================
# 수정 이력
# ============================================================
# 2026-01-15 김택권: 초기 생성
#   - EmailService 클래스 생성
#   - SMTP 설정 (환경변수에서 읽어오기)
#   - send_password_reset_email 메서드 구현 (인증 코드 이메일 발송)
#   - send_password_reset_link 메서드 구현 (비밀번호 변경 링크 이메일 발송, 대안 방법)
#   - HTML 및 텍스트 형식 이메일 지원
#   - 에러 처리 및 로깅 구현
