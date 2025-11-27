//---------------------------------------------------------------------------

#include <vcl.h>
#pragma hdrstop

#include "Msg_Thread.h"
#pragma package(smart_init)

#include "Main.h"

extern AnsiString StationName;
extern int Tester;
extern int LineName;
extern int count_all_sfc, count_all_NoDevi;

//---------------------------------------------------------------------------

__fastcall Msg_Thread::Msg_Thread(bool CreateSuspended,
                                  AnsiString rev_msg,
                                  AnsiString rev_ip)
    : TThread(CreateSuspended)
{
    this->thread_rev_msg = rev_msg;
    this->thread_rev_ip  = rev_ip;
}

//---------------------------------------------------------------------------
// Đặt tên thread cho dễ debug trong IDE
void Msg_Thread::SetName()
{
    THREADNAME_INFO info;
    info.dwType     = 0x1000;
    info.szName     = "Msg_Thread";
    info.dwThreadID = -1;
    info.dwFlags    = 0;

    __try
    {
        RaiseException(0x406D1388, 0, sizeof(info) / sizeof(DWORD),
                       (DWORD*)&info);
    }
    __except (EXCEPTION_CONTINUE_EXECUTION)
    {
    }
}

//---------------------------------------------------------------------------
// HÀM MỚI: xử lý 1 batch kết quả từ terminal (1 chuỗi dài có nhiều ',')
// Re-order theo thứ tự DSN1..DSN12 (Form1->PanelDSN[0..11])
void __fastcall Msg_Thread::ProcessTerminalBatch()
{
    const int MAX_SLOT = 12;

    // Mảng kết quả đã được reorder theo DSN1..DSN12
    AnsiString sortedToken[MAX_SLOT];

    // Chuỗi nhận được từ terminal, dạng:
    // "11PASS#SN1,12PASS#SN2,...,34PASS#SN12,C03CASTSER03"
    AnsiString msg = this->thread_rev_msg;

    while (msg.Length() > 0)
    {
        int p = msg.Pos(",");
        AnsiString token;

        if (p > 0)
        {
            token = msg.SubString(1, p - 1);
            msg   = msg.Delete(1, p); // xoá token + dấu ','
        }
        else
        {
            token = msg;
            msg   = "";
        }

        token = token.Trim();
        if (token.IsEmpty())
            continue;

        // Bỏ qua token không phải dạng PASS/FAIL (ví dụ "C03CASTSER03")
        if (!(token.Pos("PASS") || token.Pos("FAIL")))
            continue;

        // Tìm dấu '#': "11PASS#SN"
        int hashPos = token.Pos("#");
        if (hashPos == 0)
            continue;   // không có SN, bỏ qua

        // Lấy SN sau dấu '#'
        AnsiString sn = token.SubString(hashPos + 1,
                                        token.Length() - hashPos);
        sn = sn.Trim();
        if (sn.IsEmpty())
            continue;

        // Tìm SN này thuộc DSN slot nào (0..11)
        int realSlot = -1;
        for (int i = 0; i < MAX_SLOT; i++)
        {
            // ⚠ Đảm bảo Form1->PanelDSN[i] đã gán đúng DSN1..DSN12
            if (Form1->PanelDSN[i].Trim().AnsiCompareIC(sn) == 0)
            {
                realSlot = i;
                break;
            }
        }

        if (realSlot >= 0 && realSlot < MAX_SLOT)
        {
            // Nếu slot trống thì gán; nếu đã có thì thôi (tránh đè)
            if (sortedToken[realSlot].IsEmpty())
            {
                sortedToken[realSlot] = token;
            }
        }
        else
        {
            // SN không thuộc DSN1..DSN12, có thể log nếu muốn:
            // Form1->redt1->Lines->Add("Unknown SN from terminal: " + sn);
        }
    }

    // Sau khi reorder xong → xử lý từng DUT theo thứ tự DSN1..DSN12
    for (int i = 0; i < MAX_SLOT; i++)
    {
        if (!sortedToken[i].IsEmpty())
        {
            // token vẫn dạng "11PASS#SN" → Set_Test_Status() cũ xử lý tiếp
            Set_Test_Status(sortedToken[i]);
        }
    }
}

//---------------------------------------------------------------------------

void __fastcall Msg_Thread::Execute()
{
    SetName();
    //---- Place thread code here ----

    // set online
    if (this->thread_rev_msg.Length() == 12 &&
        this->thread_rev_msg.Pos("FT2"))
    {
        RemoteHost = this->thread_rev_msg.SubString(1, 12).Trim();
        if (StationName == "PT1")
        {
            int itest = 0;
            if (RemoteHost.Pos(StationName))
            {
                if (LineName % 2 == 0)
                {
                    /*
                    // mapping cũ bị comment
                    */
                }
                else
                {
                    // dan shu
                    if      (RemoteHost.SubString(11, 2) == "01") itest = 0;
                    else if (RemoteHost.SubString(11, 2) == "02") itest = 4;
                    else if (RemoteHost.SubString(11, 2) == "03") itest = 8;
                    else
                    {
                        return;
                    }
                }
                for (int i = 0; i < 4; i++)
                {
                    Form1->pTFrame2[i + itest]->SetTestStatus("online");
                }
                Form1->bTest           = false;
                Form1->tmr_msg->Enabled = true;
                return;
            }
            return;
        }
        else if (StationName == "FT2")
        {
            int itest = 0;
            if (RemoteHost.Pos(StationName))
            {
                if (LineName % 2 == 0)
                {
                    if      (RemoteHost.SubString(11, 2) == "01") itest = 15;
                    else if (RemoteHost.SubString(11, 2) == "02") itest = 12;
                    else if (RemoteHost.SubString(11, 2) == "03") itest = 9;
                    else if (RemoteHost.SubString(11, 2) == "04") itest = 6;
                    else if (RemoteHost.SubString(11, 2) == "05") itest = 3;
                    else if (RemoteHost.SubString(11, 2) == "01") itest = 0;
                    else
                    {
                        return;
                    }
                }
                else
                {
                    // dan shu
                    if      (RemoteHost.SubString(11, 2) == "01") itest = 0;
                    else if (RemoteHost.SubString(11, 2) == "02") itest = 3;
                    else if (RemoteHost.SubString(11, 2) == "03") itest = 6;
                    else if (RemoteHost.SubString(11, 2) == "04") itest = 9;
                    else if (RemoteHost.SubString(11, 2) == "05") itest = 12;
                    else if (RemoteHost.SubString(11, 2) == "06") itest = 15;
                    else
                    {
                        return;
                    }
                }
                for (int i = 0; i < 3; i++)
                {
                    Form1->pTFrame2[i + itest]->SetTestStatus("online");
                }
                Form1->bTest           = false;
                Form1->tmr_msg->Enabled = true;
                return;
            }
            return;
        }
    }

    // set test status
    if (StationName == "PT1" || StationName == "FT2")
    {
        // Nếu là batch nhiều DUT (có PASS/FAIL + có dấu ',')
        if ((this->thread_rev_msg.Pos("PASS") ||
             this->thread_rev_msg.Pos("FAIL")) &&
            this->thread_rev_msg.Pos(",") > 0)
        {
            ProcessTerminalBatch();     // 🌟 reorder theo SN rồi xử lý
        }
        else if (this->thread_rev_msg.Length() == 12)
        {
            // Trường hợp cũ: 1 DUT, chuỗi dài 12 ký tự
            this->Set_Test_Status(this->thread_rev_msg);
        }
    }

    Form1->bTest           = false;
    Form1->tmr_msg->Enabled = true;
}

//---------------------------------------------------------------------------

void __fastcall Msg_Thread::add_dut_status(int station, AnsiString rev)
{
    Form1->dut_status[station] = rev;
}

//---------------------------------------------------------------------------

void __fastcall Msg_Thread::Set_Test_Status(AnsiString rev)
{
    AnsiString test_status;
    AnsiString i_station, i_Station_Num, i_temp;
    i_station     = rev.SubString(1, 1);
    i_Station_Num = rev.SubString(2, 1);
    i_temp        = rev.SubString(1, 2);

    if (rev.Pos("PASS") || (rev.Pos("FAIL")))
    {
        // Dùng lại mapping cũ vào dut_status[0..17]
        if      (i_temp == "11") add_dut_status(0,  rev);
        else if (i_temp == "12") add_dut_status(1,  rev);
        else if (i_temp == "13") add_dut_status(2,  rev);
        // DUT 2~3
        else if (i_temp == "21") add_dut_status(3,  rev);
        else if (i_temp == "22") add_dut_status(4,  rev);
        else if (i_temp == "23") add_dut_status(5,  rev);
        // DUT 3~3
        else if (i_temp == "31") add_dut_status(6,  rev);
        else if (i_temp == "32") add_dut_status(7,  rev);
        else if (i_temp == "33") add_dut_status(8,  rev);
        // DUT 4~3
        else if (i_temp == "41") add_dut_status(9,  rev);
        else if (i_temp == "42") add_dut_status(10, rev);
        else if (i_temp == "43") add_dut_status(11, rev);
        // DUT 5~3
        else if (i_temp == "51") add_dut_status(12, rev);
        else if (i_temp == "52") add_dut_status(13, rev);
        else if (i_temp == "53") add_dut_status(14, rev);
        // DUT 6~3
        else if (i_temp == "61") add_dut_status(15, rev);
        else if (i_temp == "62") add_dut_status(16, rev);
        else if (i_temp == "63") add_dut_status(17, rev);
    }

    if (rev.Pos("RUN"))
    {
        test_status = "RUN";
    }
    else if (rev.Pos("PASS"))
    {
        test_status = rev.SubString(3, 10);
    }
    else if (rev.Pos("FAIL"))
    {
        test_status = rev.SubString(3, 10);
    }
    else if (rev.Pos("Lock"))
    {
        test_status = "Lock";
    }

    if (LineName % 2 == 0)
    {
        if      (i_station == "6")
            Form1->pTFrame2[i_Station_Num.ToInt() - 1      ]->SetTestStatus(test_status);
        else if (i_station == "5")
            Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 3  ]->SetTestStatus(test_status);
        else if (i_station == "4")
            Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 6  ]->SetTestStatus(test_status);
        else if (i_station == "3")
            Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 9  ]->SetTestStatus(test_status);
        else if (i_station == "2")
            Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 12 ]->SetTestStatus(test_status);
        else if (i_station == "1")
            Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 15 ]->SetTestStatus(test_status);
    }
    else
    {
        if (StationName == "FT2")
        {
            // L5
            if      (i_station == "1")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1     ]->SetTestStatus(test_status);
            else if (i_station == "2")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 3 ]->SetTestStatus(test_status);
            else if (i_station == "3")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 6 ]->SetTestStatus(test_status);
            else if (i_station == "4")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 9 ]->SetTestStatus(test_status);
            else if (i_station == "5")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 12]->SetTestStatus(test_status);
            else if (i_station == "6")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 15]->SetTestStatus(test_status);
        }
        else if (StationName == "PT1")
        {
            if      (i_station == "1")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1     ]->SetTestStatus(test_status);
            else if (i_station == "2")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 4 ]->SetTestStatus(test_status);
            else if (i_station == "3")
                Form1->pTFrame2[i_Station_Num.ToInt() - 1 + 8 ]->SetTestStatus(test_status);
        }
    }
}
//---------------------------------------------------------------------------
