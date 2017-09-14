//+------------------------------------------------------------------+
//|                                                       MA2040.mq4 |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Zafer Satılmış"
#property link      "zp.4rex@gmail.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#define SUCCESS (0)
#define FAILURE (-1)

#define DBG_MODE
#ifdef DBG_MODE
	#define DBG_MSG(x)	(x)
#else
	#define DBG_MSG(x)
#endif


#define AUTO_ORDER_KEY      (6666)

//--- Inputs
input double Lots              = 0.01;
input double MaximumRisk       = 0.02;
input bool   ManuelOrder       = FALSE;
input int    FastMovingPeriod  = 22;
input int    SlowMovingPeriod  = 50;
input int    TrendMovingPeriod = 100;
input int    MAMovingShift     = 0;
input int    StopLoss = 250;
input int    ToleranceSL = 100;

double  gStopLossPrice;
int     gSLCounter; //stop loss counter 
int     gBars;

enum OrderCloseType_
{
    EN_ORDER_CLOSE_SL, //stop loss
    EN_ORDER_CLOSE_TP, //take profit
    EN_ORDER_CLOSE_MC, //manuel close

    EN_ORDER_NONE,
    
}OrderCloseType;

enum OrderOpenMethod_
{
    EN_ORDER_METHOD_NEW_TREND = 1,
    EN_ORDER_METHOD_TREND_CONTINUES,
    EN_ORDER_METHOD_TREND_TOUCH_MA,
    EN_ORDER_METHOD_MANUEL_ORDER,

    EN_ORDER_METHOD_NONE,
}OrderOpenMethod;

struct lastOrderDetails_
{
    int      orderType;
    datetime orderOpenTime;
    double   orderOpenPrice;
    double   orderClosePrice;
    int      orderCloseTip;
    double   orderLot;
    int      orderOpenMethod;
}lastOrderDetails;
 
int OnInit()
{
    // create timer
    //EventSetTimer(60);

    clearGlobalOrderData();

    DBG_MSG(Print("##> StopLoss: ", StopLoss, "ToleranceSL: ", ToleranceSL));
    
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	//destroy timer
   	EventKillTimer();      
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

bool orderOpened(void)
{
    bool retVal = FALSE;

    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == FALSE)
        {
            break;
        }
        if((OrderSymbol() == Symbol()) && (OrderMagicNumber() == AUTO_ORDER_KEY))
        {
            if((OrderType() == OP_BUY) || (OrderType() == OP_SELL))
            {
                retVal = TRUE;                                
            }
        }
    }  

    return retVal;

}

void clearGlobalOrderData(void)
{
    //clear bars number data
    gBars = 0;

    //clear SL counter
    gSLCounter = 0;

    //clear stop loss price
    gStopLossPrice = 0;

    //clear last order details
    lastOrderDetails.orderOpenTime = 0;
    lastOrderDetails.orderType = 0;
    lastOrderDetails.orderOpenPrice = 0;
    lastOrderDetails.orderLot = 0;
    lastOrderDetails.orderCloseTip = EN_ORDER_NONE;
    lastOrderDetails.orderClosePrice = 0; 
    lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_NONE;
}

bool isNewBar(int lastBarsNumber)
{    
    bool retVal = FALSE;
    
    if(lastBarsNumber < Bars(_Symbol,_Period))
    {
        retVal = TRUE;
    }
    
    return retVal;
}

double calculateStopLossPrice(double price, int orderType)
{
    double stopLossPrice = 0;
    
    if (OP_SELL == orderType)
    {        
        stopLossPrice = price + (Point * StopLoss);                                 
        DBG_MSG(Print("##>SL: Order type SELL: ", stopLossPrice));       
    }
    else if (OP_BUY == orderType)
    {        
        stopLossPrice = price - (Point * StopLoss);
		DBG_MSG(Print("##>SL: Order type BUY: ", stopLossPrice)); 
    }    
    
    return stopLossPrice;
}

int openOrderAndSetStopLoss(int ordertype, double lot, double orderPrice)
{
    int retVal = FALSE;
    int orderRet;

    orderRet = OrderSend(Symbol(), ordertype, lot, orderPrice, 3, 0, 0, "Auto Trading by ZAFER", AUTO_ORDER_KEY, 0, Red);
    if (orderRet > 0)
    {
        //calculate SL
    	gStopLossPrice = calculateStopLossPrice(orderPrice, ordertype);

        //load current order details
        lastOrderDetails.orderOpenTime = TimeCurrent();
        lastOrderDetails.orderType = ordertype;
        lastOrderDetails.orderOpenPrice = orderPrice;
        lastOrderDetails.orderLot = lot;                               

    	retVal = TRUE; //order opened successfull

    	if(TRUE == OrderSelect(orderRet, SELECT_BY_TICKET, MODE_TRADES))
    	{
        	DBG_MSG(Print("##> Order opened: ", OrderOpenPrice()));
        	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), gStopLossPrice, 0, 0, Green))
        	{
    	    	gSLCounter = 1; 
    	    	
    	    	//load current order details
    	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_SL;
    	    	lastOrderDetails.orderClosePrice = gStopLossPrice;
        	}
          #ifdef (DBG_MODE)
        	else
        	{
        	    Print("##> OrderModify error: ", GetLastError());
        	}
          #endif
    	}
    }
#ifdef (DBG_MODE)
    else
    {
      Print("##> Error opening order : ", GetLastError());
    } 
#endif

    return retVal;

}

bool checkNewTrendOrder(void)
{
    bool    retVal = FALSE;
	double  nowMASlow;
	double  prevMASlow;

	double  nowMAFast;
	double  prevMAFast;
  
/*    //go trading only for first tiks of new bar
    if(Volume[0] > 1)
    {
        return;
    }*/
   
	//get Moving Average 
	prevMASlow = iMA(NULL, 0, SlowMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 1);
	nowMASlow  = iMA(NULL, 0, SlowMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);

	prevMAFast = iMA(NULL, 0, FastMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 1);
	nowMAFast  = iMA(NULL, 0, FastMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);

    //-------------------------------- SELL -----------------------------//
	//sell conditions, masfast crossed under maSlow
	if ((prevMAFast > prevMASlow) && (nowMAFast < nowMASlow)) //MAp MAi keserek altına iniyor
	{
		DBG_MSG(Print("##> Sell rule 1 is OK. MA_FAST < MA_SLOW"));
	  
		//sell rule 2: current price should be lower than nowMAFast
		if (/*(Close[1] < nowMAFast) &&*/ (Close[0] < nowMAFast))
        {            
            //clear global data and open new order
            clearGlobalOrderData(); 
            
			retVal = openOrderAndSetStopLoss(OP_SELL, Lots, Bid);
			if (TRUE == retVal)
			{
                lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_NEW_TREND;
			}
		}		           
	}	    
     //-------------------------------- BUY -----------------------------//
    //MA fast crossed up MA slow
    else if ((prevMASlow > prevMAFast) && (nowMASlow < nowMAFast))
    {
        DBG_MSG(Print("##> BUY rule 1 is OK. MA_FAST > MA_SLOW"));
           
        //sell rule 2: current price should be bigger than nowMAFast
        if (/*(Close[1] > nowMAFast) && */(Close[0] > nowMAFast))
        {      
            //clear global data and open new order
            clearGlobalOrderData();         
            
            retVal = openOrderAndSetStopLoss(OP_BUY, Lots, Ask);
            if (TRUE == retVal)
			{
                lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_NEW_TREND;
			}
        }               
    }	

    return retVal;
    
}


bool checkPriceTouchedMAOrder(void)
{
    bool    retVal = FALSE;    
    
	double  nowMASlow;
	double  nowMAFast;
	double  nowTrendMA;

    //wait firstly open trend order
    if (EN_ORDER_NONE == lastOrderDetails.orderCloseTip)
    {    
        return FALSE;
    }
  
/*    //go trading only for first tiks of new bar
    if(Volume[0] > 1)
    {
        return;
    }*/
   
	//get Moving Average 
	nowMAFast   = iMA(NULL, 0, FastMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);
	nowMASlow   = iMA(NULL, 0, SlowMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);
    nowTrendMA  = iMA(NULL, 0, TrendMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);


    /************************ SELL POSITION ***************************/
    if (OP_SELL == lastOrderDetails.orderType)
    {    
        //for sell position, price should be under the all trend line.
        if ((nowMAFast > Close[0]) && (nowMASlow > Close[0]) && (nowTrendMA > Close[0]))
        {        
            if ((nowMAFast < nowMASlow) && (nowMASlow < nowTrendMA))
            {
                //two prev bar should be closed above MAfast and prev bar closed under MAfast
                if ((Close[2] >= nowMAFast) && (Close[1] <= nowMAFast))                
                {
                    //clear global data and open new order
                    clearGlobalOrderData();  

                    retVal = openOrderAndSetStopLoss(OP_SELL, Lots, Bid);
                    if (TRUE == retVal)
        			{
                        lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_TREND_TOUCH_MA;
        			}
                }            
            }
        }
    }
    else if (OP_BUY == lastOrderDetails.orderType)
    {
        //for sell position, price should be under the all trend line.
        if ((nowMAFast < Close[0]) && (nowMASlow < Close[0]) && (nowTrendMA < Close[0]))
        {        
            if ((nowMAFast > nowMASlow) && (nowMASlow > nowTrendMA))
            {
                //two prev bar should be closed above MAfast and prev bar closed under MAfast
                if ((Close[2] <= nowMAFast) && (Close[1] >= nowMAFast))                
                {
                    //clear global data and open new order
                    clearGlobalOrderData();  
                    
                    retVal = openOrderAndSetStopLoss(OP_BUY, Lots, Ask);
                    if (TRUE == retVal)
        			{
                        lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_TREND_TOUCH_MA;
        			}
                }             
            }
        }
    }   

    return retVal;
}

bool checkPriceTrendOrder(void)
{
    bool retVal = FALSE;
    
	double  nowMASlow;
	double  nowMAFast;
	double  nowTrendMA;

	double newOrderPriceStation = 0;

    //wait firstly open trend order
    if (EN_ORDER_NONE == lastOrderDetails.orderCloseTip)
    {       
        return FALSE;
    }
  
/*    //go trading only for first tiks of new bar
    if(Volume[0] > 1)
    {
        return;
    }*/
   
	//get Moving Average 
	nowMAFast   = iMA(NULL, 0, FastMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);
	nowMASlow   = iMA(NULL, 0, SlowMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);
    nowTrendMA  = iMA(NULL, 0, TrendMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);  

    if (0 == gBars)
    {
        gBars = Bars(_Symbol, _Period);
    }

    /************************ SELL POSITION ***************************/

    if (OP_SELL == lastOrderDetails.orderType)
    {    
        //for sell position, price should be under the all trend line.
        if ((nowMAFast > Close[0]) && (nowMASlow > Close[0]) && (nowTrendMA > Close[0]))
        {        
            if ((nowMAFast < nowMASlow) && (nowMASlow < nowTrendMA))
            {
                if (TRUE == isNewBar(gBars))
                {
                    //check closed bar, it should be under the last order sl price
                    if (EN_ORDER_CLOSE_TP == lastOrderDetails.orderCloseTip)
                    {
                        newOrderPriceStation = lastOrderDetails.orderClosePrice;
                    }
                    else if (EN_ORDER_CLOSE_SL == lastOrderDetails.orderCloseTip)
                    {
                        newOrderPriceStation = lastOrderDetails.orderOpenPrice;
                    }
                    
                    if ((0 != newOrderPriceStation) && (Close[1] <= newOrderPriceStation))
                    {                                                
                        clearGlobalOrderData();  
                        
                        retVal = openOrderAndSetStopLoss(OP_SELL, Lots, Bid);
                        if (TRUE == retVal)
        			    {
                            lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_TREND_CONTINUES;
        			    }
                    }                                        
                }        
            }       
        }
    }
     /************************ BUY POSITION ***************************/
    else if (OP_BUY == lastOrderDetails.orderType)
    {
        //for buy position, price should be above the all trend line.
        if ((nowMAFast < Close[0]) && (nowMASlow < Close[0]) && (nowTrendMA < Close[0]))
        {        
            if ((nowMAFast > nowMASlow) && (nowMASlow > nowTrendMA))
            {
                if (TRUE == isNewBar(gBars))
                {                    
                    //check closed bar, it should be under the last order sl price
                    if (EN_ORDER_CLOSE_TP == lastOrderDetails.orderCloseTip)
                    {
                        newOrderPriceStation = lastOrderDetails.orderClosePrice;
                    }
                    else if (EN_ORDER_CLOSE_SL == lastOrderDetails.orderCloseTip)
                    {
                        newOrderPriceStation = lastOrderDetails.orderOpenPrice;
                    }                    
                    
                    if ((0 != newOrderPriceStation) && (Close[1] >= newOrderPriceStation))
                    {
                        clearGlobalOrderData();  

                        DBG_MSG(Print("##> checkPriceTrendOrder BUY"));
                        retVal = openOrderAndSetStopLoss(OP_BUY, Lots, Ask);
                        if (TRUE == retVal)
        			    {
                            lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_TREND_CONTINUES;
        			    }
                    }                                        
                }
            }       
        }
    }
    
    return retVal;
}

bool openManuelOrder(void)
{
    bool retVal = FALSE;
    
	double  nowMASlow;
	double  nowMAFast;
	double  nowTrendMA;
  
/*    //go trading only for first tiks of new bar
    if(Volume[0] > 1)
    {
        return;
    }*/
   
	//get Moving Average 
	nowMAFast   = iMA(NULL, 0, FastMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);
	nowMASlow   = iMA(NULL, 0, SlowMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);
    nowTrendMA  = iMA(NULL, 0, TrendMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);  

    //for sell position, price should be under the all trend line.
    if ((nowMAFast > Close[0]) && (nowMASlow > Close[0]) && (nowTrendMA > Close[0]))
    {        
        if ((nowMAFast < nowMASlow) && (nowMASlow < nowTrendMA))
        {
            retVal = openOrderAndSetStopLoss(OP_SELL, Lots, Bid);
            if (TRUE == retVal)
    	    {
                lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_MANUEL_ORDER;
    	    }
        }
    }

    //for buy position, price should be above the all trend line.
    if ((nowMAFast < Close[0]) && (nowMASlow < Close[0]) && (nowTrendMA < Close[0]))
    {        
        if ((nowMAFast > nowMASlow) && (nowMASlow > nowTrendMA))
        {
            //clear global data and open new order
            clearGlobalOrderData();         
            
            retVal = openOrderAndSetStopLoss(OP_BUY, Lots, Ask);
            if (TRUE == retVal)
			{
                lastOrderDetails.orderOpenMethod = EN_ORDER_METHOD_MANUEL_ORDER;
			}        
        }
    }

    return retVal;

}

bool checkForOpen(void)
{
    int retVal = FALSE;

    //trendin yön değiştirirse işlem aç    
    if (FALSE == checkNewTrendOrder())
    {
        /* Fiyat MA fast üzerinde kapattısa ve tekrar trend yönüne
         * döndüyse yeni işlemi burada aç */
        if (FALSE == checkPriceTouchedMAOrder())
        {
            /* Fiyat trend yönünde hareketine kaldığı yerden devam 
             * ederse yeni işlem aç */        
            retVal = checkPriceTrendOrder();            
        }
    }   

    if (TRUE == ManuelOrder)
    {
        openManuelOrder();
    }

    return retVal;
}


int trailingStop(void)
{
    double orderOpenPrice;
    int retVal = FALSE;
    
	for(int i = 0; i < OrdersTotal(); i++)
	{
		if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == FALSE)
		{
			break;
		}
		
		if((OrderMagicNumber() != AUTO_ORDER_KEY) || (OrderSymbol() != Symbol()))
		{
		 	continue;
		}

        orderOpenPrice = OrderOpenPrice();
	  
	  	if(OrderType() == OP_SELL)
	  	{
	  	    if (0 == gSLCounter) //işlem açılışında SL ayarlanmadıysa burada kontrol et
	  	    {
	  	        gStopLossPrice = calculateStopLossPrice(OrderOpenPrice(), OP_SELL);

                //if session closed and open again we should set first SL
                //but if first SL exist we can not set same position. we moved litte bit.
	  	        gStopLossPrice += Point * 5; // 
	  	         
		    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), gStopLossPrice, 0, 0, Green))
		    	{
                    gSLCounter = 1;

        	    	//load current order details
        	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_SL;
        	    	lastOrderDetails.orderClosePrice = gStopLossPrice;
                        
                    retVal = SUCCESS;

                    DBG_MSG(Print("##> trailingStop > first SL added "));
		    	}	  	        
	  	    }
	  	    else if (orderOpenPrice > Close[0])  //price moving down
	  	    {	
                if (1 == gSLCounter) //kaar alanında ilk SL
                {
                    if (gStopLossPrice > orderOpenPrice)
                    {
                        //kaar alanında ilk SL için fiyat ilerlemiş mi
                        if ((orderOpenPrice - Close[0]) >= (StopLoss * Point))
                        {    
                            //kaar alanında ilk SL ayarlanır
                        	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] + (Point*ToleranceSL)), 0, 0, Green))
                        	{
                            	//load new sl price
                        	    gStopLossPrice = Close[0] + (Point*ToleranceSL);
                        	    
                    	    	//load current order details
                    	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                    	    	lastOrderDetails.orderClosePrice = gStopLossPrice;  
                        	}
                          #ifdef DBG_MODE	    			      
                        	else
                            {
                                Print("##> trailingStop > Modify Order Error ",GetLastError());
                            }
                          #endif    			    	
                        }
    			    }
    			    //tolerans kadar geride bırakılan SL taşınır, çünkü fiyat istenilen yönde ilerliyor.
    			    else if ((gStopLossPrice - Close[0]) >= ((2*ToleranceSL)*Point)) 
    			    {
                    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] + (Point*ToleranceSL)), 0, 0, Green))
                    	{
                            //load new sl price                    	
                    	    gStopLossPrice = Close[0] + (Point*ToleranceSL);
                    	    
                	    	//load current order details
                	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                	    	lastOrderDetails.orderClosePrice = gStopLossPrice;
                    	    
                    	    gSLCounter = 2;
                    	}
                      #ifdef DBG_MODE	    			      
                    	else
                        {
                            Print("##> trailingStop > Modify Order Error ",GetLastError());
                        }
                      #endif                         
    			    }
    			    
                }    
                else // kaar alanında ilerleme devam ediyor ve sl taşımak için uygun durum gözleniyor.
                {   
                    //tolerans kadar geride bırakılan SL yerine taşır
                    if ((orderOpenPrice - Close[0]) >= (((gSLCounter * StopLoss) + ToleranceSL) * Point))
                    {
                    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] + (Point*ToleranceSL)), 0, 0, Green))
                    	{
                        	//load new sl price
                    	    gStopLossPrice = Close[0] + (Point*ToleranceSL);

                	    	//load current order details
                	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                	    	lastOrderDetails.orderClosePrice = gStopLossPrice;
                    	    
                    	    gSLCounter++;
                    	}
                      #ifdef DBG_MODE	    			      
                    	else
                        {
                            Print("##> trailingStop > Modify Order Error ",GetLastError());
                        }
                      #endif 
                    }
                    else if ((gStopLossPrice - Close[0]) >= (StopLoss * Point)) //fiyat SL kadar ilerler ile yeni SL ayarlanır
                    {
                    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] + (Point*ToleranceSL)), 0, 0, Green))
                    	{
                        	//load new sl price
                    	    gStopLossPrice = Close[0] + (Point*ToleranceSL); 

                	    	//load current order details
                	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                	    	lastOrderDetails.orderClosePrice = gStopLossPrice;                    	    
                    	}
                      #ifdef DBG_MODE	    			      
                    	else
                        {
                            Print("##> trailingStop > Modify Order Error ",GetLastError());
                        }
                      #endif 
                    }
                }
		    }
        }
        
        else if (OrderType() == OP_BUY)
        {
	  	    if (0 == gSLCounter) //işlem açılışında SL ayarlanmadıysa burada kontrol et
	  	    {
	  	        gStopLossPrice = calculateStopLossPrice(OrderOpenPrice(), OP_BUY);

	  	        //if session closed and open again we should set first SL
                //but if first SL exist we can not set same position. we moved litte bit.
	  	        gStopLossPrice += Point * 5; // 
	  	        
		    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), gStopLossPrice, 0, 0, Green))
		    	{
		    	    //load current order details
        	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_SL;
        	    	lastOrderDetails.orderClosePrice = gStopLossPrice;
        	    	
                    gSLCounter = 1;
                    retVal = SUCCESS;
		    	}	  	        
	  	    }
	  	    else if (orderOpenPrice < Close[0]) //price moving down
	  	    {	
                if (1 == gSLCounter) // first sl 
                {
                    if (gStopLossPrice < orderOpenPrice) // set first SL price
                    {
                        if ((Close[0] - orderOpenPrice) >= (StopLoss * Point))
                        {                    
                        	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] - (Point*ToleranceSL)), 0, 0, Green))
                        	{
                            	//load new sl price
                        	    gStopLossPrice = Close[0] - (Point*ToleranceSL);

                        	    //load current order details
                    	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                    	    	lastOrderDetails.orderClosePrice = gStopLossPrice;                    	    	                        	    
                        	}
                          #ifdef DBG_MODE	    			      
                        	else
                            {
                                Print("##> trailingStop > Modify Order Error ",GetLastError());
                            }
                          #endif    			    	
                        }
    			    }
    			    else if ((Close[0] - gStopLossPrice) >= ((2*ToleranceSL)*Point)) //move tolerance 
    			    {
                    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] - (Point*ToleranceSL)), 0, 0, Green))
                    	{
                        	//load new sl price
                    	    gStopLossPrice = Close[0] - (Point*ToleranceSL);

                    	    //load current order details
                	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                	    	lastOrderDetails.orderClosePrice = gStopLossPrice;
                    	    
                    	    gSLCounter = 2;
                    	}
                      #ifdef DBG_MODE	    			      
                    	else
                        {
                            Print("##> trailingStop > Modify Order Error ",GetLastError());
                        }
                      #endif                         
    			    }
    			    
                }    
                else
                {
                    if ((Close[0] - orderOpenPrice) >= (((gSLCounter * StopLoss) + ToleranceSL) * Point))
                    {
                    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] - (Point*ToleranceSL)), 0, 0, Green))
                    	{
                    	    //load new sl price
                    	    gStopLossPrice = Close[0] - (Point*ToleranceSL);

                    	    //load current order details
                	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                	    	lastOrderDetails.orderClosePrice = gStopLossPrice;            
                	    	
                    	    gSLCounter++;
                    	}
                      #ifdef DBG_MODE	    			      
                    	else
                        {
                           Print("##> trailingStop > Modify Order Error ",GetLastError());
                        }
                      #endif 
                    }
                    else if ((Close[0] - gStopLossPrice) >= (StopLoss * Point))
                    {
                    	if (TRUE == OrderModify(OrderTicket(), OrderOpenPrice(), (Close[0] - (Point*ToleranceSL)), 0, 0, Green))
                    	{
                    	    //load new sl price
                    	    gStopLossPrice = Close[0] - (Point*ToleranceSL); 

                    	    //load current order details
                	    	lastOrderDetails.orderCloseTip = EN_ORDER_CLOSE_TP;
                	    	lastOrderDetails.orderClosePrice = gStopLossPrice;                    	    
                    	}
                      #ifdef DBG_MODE	    			      
                    	else
                        {
                            Print("##> trailingStop > Modify Order Error ",GetLastError());
                        }
                      #endif 
                    }
                }
		    }   
        }
   }
    
    return 0;
}

int checkForClose(void)
{
    int    retVal = FALSE;
	double nowMASlow;
	double prevMASlow;

	double nowMAFast;
	double prevMAFast;  

   /*
//--- go trading only for first tiks of new bar
   if(Volume[0] > 1)
   {
      return;
   }*/
   
	//get Moving Average 
	 prevMASlow = iMA(NULL, 0, SlowMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 1);
	 nowMASlow  = iMA(NULL, 0, SlowMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);

	 prevMAFast = iMA(NULL, 0, FastMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 1);
	 nowMAFast  = iMA(NULL, 0, FastMovingPeriod, MAMovingShift, MODE_EMA, PRICE_CLOSE, 0);
   
	for(int i = 0; i < OrdersTotal(); i++)
	{
		if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false)
		{
			break;
		}
		if(OrderMagicNumber()!=AUTO_ORDER_KEY || OrderSymbol()!=Symbol())
		{
		 	continue;
		}
	  
	  	if(OrderType() == OP_BUY)
	  	{
	    	if ((prevMAFast > prevMASlow) && (nowMAFast < nowMASlow))
	     	{
	        	if(FALSE == OrderClose(OrderTicket(), OrderLots(), Bid, 3, White))
	        	{
	           		DBG_MSG(Print("##>checkForClose > OrderClose error ",GetLastError()));
	        	}
	        	else
	        	 Print("##>checkForClose > Order closed SUCCESS");
	     	}
	     	break;
	  	}  
	     
	  	if(OrderType() == OP_SELL)
	  	{
	     	if ((prevMASlow > prevMAFast) && (nowMASlow < nowMAFast))
	     	{
	        	if(FALSE == OrderClose(OrderTicket(), OrderLots(), Ask, 3, White))
	        	{
	           		DBG_MSG(Print("##>checkForClose > OrderClose error ",GetLastError()));
	        	}
	        	else
	        	    Print("##>checkForClose > Order closed SUCCESS");
	     	}
	     	break;
	  	}       
	} 

	return retVal;
}

void OnTick(void)
{
    //--- check for history and trading
    if((Bars < 100) || (IsTradeAllowed() == FALSE))
    {
        return;
    }
    
    //check open order by current symbol
    if(orderOpened() == FALSE)
    { 
        checkForOpen();
    }
    else
    {           
        trailingStop();
        checkForClose();
    }
//---   
}



//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
