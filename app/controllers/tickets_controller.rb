class TicketsController < ApplicationController
  before_filter :authorize, :except => [:paypal_ipn, :paypal_return, :paypal_cancel, :cancel_purchase]
 
  # This action is for when the buyer returns to your site from PayPal
  def paypal_return
       user_id = params[:user_id]
       @user = User.find(user_id)
          session[:user_id] = @user[:id]
          session[:user_email] = @user[:email]
       #render :text => params   
       if Purchase.exists?(params[:id])
           redirect_to(:action=>'order_confirmed/'+params[:id].to_s)
       else
         flash[:notice] = I18n.t 'event.purchase.pur_can'
         redirect_to(:controller => 'home', :action=>'index') 
       end      
  end
   
  # This action is for when the buyer cancels
  def paypal_cancel
      user_id = params[:user_id]
       @user = User.find(user_id)
          session[:user_id] = @user[:id]
          session[:user_email] = @user[:email]
          
      cancel_purchase(params[:id])
      flash[:notice] = I18n.t 'event.purchase.pur_can'
      redirect_to(:controller => 'home', :action=>'index') 
  end
   
  def paypal_ipn
        
        
        @status=params['payment_status'];
        @custom=params['custom'].split('#')
        
         @user_id=@custom[1].to_i
         @user = User.find(@user_id)
         session[:user_id] = @user[:id]
         session[:user_email] = @user[:email]
                          
                          
        @pay_id=@custom[2].to_i
        @custom_amt=@custom[0].to_f
        
        @pay_gross=params['mc_gross']
        
        @payee_email=params['payer_email']
        @payer_status =params['payer_status']
        
        @txn_id=params['txn_id']
        
        @chk_transaction_id = Purchase.where(:txn_id => @txn_id).count
       
        #UserMailer.confirm_paypal(@status.downcase,@pay_gross,@custom_amt,@chk_transaction_id,@txn_id,@payee_email,@pay_id).deliver
        
        if((@status.downcase =='completed' || @status.downcase=='pending') && (@pay_gross.to_f==@custom_amt.to_f || @pay_gross.to_f>@custom_amt.to_f) && @chk_transaction_id==0)
            UserMailer.confirm_paypal(@status.downcase,@pay_gross,@custom_amt,@chk_transaction_id,@txn_id,@payee_email,@pay_id).deliver
            
            Purchase.update_all(['txn_id=?, payer_email=?, payment=1', @txn_id, @payee_email], ['id=? or transaction_key=?', @pay_id.to_i, @pay_id.to_i])
            
            flash[:notice1] = I18n.t 'event.purchase.pur_suc'
        else
            flash[:notice] = I18n.t 'event.purchase.pur_can'
            @pur = Purchase.find(@pay_id)
            if @pur[:payment]==0
              cancel_purchase(@pur[:id])
            end  
             
        end  
  end 
  
  def rename_pdf
    @purchase = Purchase.find(:all, :conditions => ['ticket_id > 0'])
    for @pur in @purchase
      # @pur = Purchase.find(1)
       @event = Event.find(@pur[:event_id])
       @user = User.find(@pur[:user_id])
       @timestamp = Time.now.to_i.to_s+@pur[:id].to_s
       
       if @user[:first_name]!='' && @user[:first_name]!=nil && @user[:id]!=35
         @timestamp = @user[:first_name]+'_'+@timestamp
       end
       
       @random_no = @event[:event_title].gsub(" ", "_")+@timestamp
       @pur[:random_no] = @random_no
       @pur.save
       generate_pdf(@pur, @event)
     end
     render :text => @random_no
  end
    
  def purchase
     @site = SiteSetting.find(:first)
     @event = Event.find(params[:event_id])
     @org_id = @event[:organizer_id]
     @event_theme = EventTheme.one_theme(@event[:id])
     if @event_theme
     else @event_theme = Theme.find_first_theme
     end
     
     lang = Language.find_name(@event[:language_id])
     set_locale(lang)
     @meta_title = @event[:event_title]#I18n.t 'meta_title.ticket_purchase'
     @meta_keyword = @event[:event_title].gsub(" ", ",")
     @meta_desc = @event[:event_title]+ ' -- '+@event[:event_start_date_time].strftime('%A, %B %d, %Y').to_s+' -- '+@event[:organizer_host]
     
     @questions = Question.find(:all, :conditions => ['event_id=? AND que_type!="waiver" AND (rules="11" or rules="1")', @event[:id]])
     @waivers = Question.find(:all, :conditions => ['event_id=? AND que_type="waiver" AND (rules="11" or rules="1")', @event[:id]])
    
     @user = User.find(session[:user_id])
     @timestamp = Time.now.to_i.to_s
     
     if @user[:first_name]!='' && @user[:first_name]!=nil
       @timestamp = @user[:first_name]+'_'+@timestamp
     end
     
     @random_no = @event[:event_title].gsub(" ", "_")+@timestamp
     @barcode = SecureRandom.hex(10)
     
     @updates = EventUpdate.find(:all, :conditions => ['event_id=?', @event[:id]])
     @one_theme = @event_theme
     render :layout => 'application_login'
   # render :text => params
  end
  
  def add_attendee
     @site = SiteSetting.find(:first)
     @event = Event.find(params[:event_id])
     @org_id = @event[:organizer_id]
     
     @event_theme = EventTheme.one_theme(@event[:id])
     if @event_theme
     else @event_theme = Theme.find_first_theme
     end
     
     @event_attendee = Attendee.find(:first, :conditions => ['event_id=?', @event[:id]])
     if @event_attendee
     else @event_attendee = Attendee.new
     end
     
     @questions = Question.find(:all, :conditions => ['event_id=? AND que_type!="waiver" AND (rules="11" or rules="1")', @event[:id]])
     @waivers = Question.find(:all, :conditions => ['event_id=? AND que_type="waiver" AND (rules="11" or rules="1")', @event[:id]])
     
    
     @barcode = SecureRandom.hex(10)
     @user = User.find(session[:user_id])
     @timestamp = Time.now.to_i.to_s
     
     if @user[:first_name]!='' && @user[:first_name]!=nil
       @timestamp = @user[:first_name]+'_'+@timestamp
     end
     
     @random_no = @event[:event_title].gsub(" ", "_")+@timestamp
     
     @updates = EventUpdate.find(:all, :conditions => ['event_id=?', @event[:id]])
     @one_theme = @event_theme
     render :layout => 'application_login'
  end
  
  def place_order
   
    if request.post?
      
        respond_to do |format|
            @pur_add = Purchase.new(params[:purchase_addresse])
            @pur_add[:first_name] = params[:first_name][0]
            @pur_add[:last_name] = params[:last_name][0]
            @pur_add[:email] = params[:email][0]
            
            @eve = Event.find(@pur_add[:event_id])
            lang = Language.find_name(@eve[:language_id])
            set_locale(lang)
    
            
            
            if params[:ticket_ids]
              @pur_add[:all_ids] = params[:ticket_ids].join(',')
            end
            
            if params[:ticket_qtys]
              @pur_add[:all_qtys] = params[:ticket_qtys].join(',')
            end
            
            if params[:ticket_totals]
              @pur_add[:all_totals] = params[:ticket_totals].join(',')
            end
            
            @pur_add.save
            
            
            
             if @pur_add[:total] > 0 
               @wallet = Wallet.new
               @wallet[:credit] = @pur_add[:ticket_amt]
               @wallet[:purchase_id] = @pur_add[:id]
               @wallet[:user_id] = @eve[:user_id]
               @wallet[:event_id] = @eve[:id]
               @wallet.save
             end   
            
             @questions = Question.find(:all, :conditions => ['event_id=? AND que_type!="waiver" AND (rules="11" or rules="1")', @eve[:id]])
             @waivers = Question.find(:all, :conditions => ['event_id=? AND que_type="waiver" AND (rules="11" or rules="1")', @eve[:id]]) 
             
            if params[:ctype]=='1'
                  
                  if params[:prefix]
                      @pur_add[:prefix] = params[:prefix][0]
                  end
                  
                  if params[:suffix]      
                      @pur_add[:suffix] = params[:suffix][0]
                  end
                   
                  if params[:home_phone]      
                      @pur_add[:home_phone] = params[:home_phone][0]
                  end
                  
                  if params[:cell_phone]      
                      @pur_add[:cell_phone] = params[:cell_phone][0]
                  end
                  
                  ### bill address
                  if params[:bill_add1]     
                      @pur_add[:bill_add1] = params[:bill_add1][0]
                  end
                  
                  if params[:bill_add2]     
                      @pur_add[:bill_add2] = params[:bill_add2][0]
                  end
                  
                  if params[:bill_city]     
                      @pur_add[:bill_city] = params[:bill_city][0]
                  end
                  
                  if params[:bill_state]     
                      @pur_add[:bill_state] = params[:bill_state][0]
                  end
                  
                  if params[:bill_zip]     
                      @pur_add[:bill_zip] = params[:bill_zip][0]
                  end
                  
                  if params[:bill_country]     
                      @pur_add[:bill_country] = params[:bill_country][0]
                  end
                  
                  #####  home address
                  if params[:home_add1]     
                      @pur_add[:home_add1] = params[:home_add1][0]
                  end
                  
                  if params[:home_add2]     
                      @pur_add[:home_add2] = params[:home_add2][0]
                  end
                  
                  if params[:home_city]     
                      @pur_add[:home_city] = params[:home_city][0]
                  end
                  
                  if params[:home_state]     
                      @pur_add[:home_state] = params[:home_state][0]
                  end
                  
                  if params[:home_zip]     
                      @pur_add[:home_zip] = params[:home_zip][0]
                  end
                  
                  if params[:home_country]     
                      @pur_add[:home_country] = params[:home_country][0]
                  end
                  
                  ######  ship country
                  
                   if params[:ship_add1]     
                      @pur_add[:ship_add1] = params[:ship_add1][0]
                  end
                  
                  if params[:ship_add2]     
                      @pur_add[:ship_add2] = params[:ship_add2][0]
                  end
                  
                  if params[:ship_city]     
                      @pur_add[:ship_city] = params[:ship_city][0]
                  end
                  
                  if params[:ship_state]     
                      @pur_add[:ship_state] = params[:ship_state][0]
                  end
                  
                  if params[:ship_zip]     
                      @pur_add[:ship_zip] = params[:ship_zip][0]
                  end
                  
                  if params[:ship_country]     
                      @pur_add[:ship_country] = params[:ship_country][0]
                  end
                  
                  #####  work address
                  
                   if params[:work_add1]     
                      @pur_add[:work_add1] = params[:work_add1][0]
                  end
                  
                  if params[:work_add2]     
                      @pur_add[:work_add2] = params[:work_add2][0]
                  end
                  
                  if params[:work_city]     
                      @pur_add[:work_city] = params[:work_city][0]
                  end
                  
                  if params[:work_state]     
                      @pur_add[:work_state] = params[:work_state][0]
                  end
                  
                  if params[:work_zip]     
                      @pur_add[:work_zip] = params[:work_zip][0]
                  end
                  
                  if params[:work_country]     
                      @pur_add[:work_country] = params[:work_country][0]
                  end
                  
                  
                  
                  if params[:work_job_title] 
                      @pur_add[:work_job_title] = params[:work_job_title][0]
                  end
                  
                  if params[:work_company] 
                      @pur_add[:work_company] = params[:work_company][0]
                  end
                  
                  
                  if params[:work_phone] 
                      @pur_add[:work_phone] = params[:work_phone][0]
                  end
                  
                  if params[:work_website] 
                      @pur_add[:work_website] = params[:work_website][0]
                  end
                  
                  if params[:work_blog] 
                      @pur_add[:work_blog] = params[:work_blog][0]
                  end
                  
                  if params[:gender] 
                      @pur_add[:gender] = params[:gender][0]
                  end
                  
                  if params[:birth_date] 
                      @pur_add[:birth_date] = params[:birth_date][0]
                  end
                  
                  if params[:age] 
                      @pur_add[:age] = params[:age][0]
                  end
                  
                  if params[:ticket_id] 
                      @pur_add[:ticket_id] = params[:ticket_id][0]
                  end
                 @pur_add.save
                 
                 
                 if  @questions.count > 0
                    
                    for q in @questions
                       if params[:que]
                          if params[:que][q[:id].to_s] 
                              @answer = Answer.new
                              @answer[:event_id] = @pur_add[:event_id]
                              @answer[:user_id] = @pur_add[:user_id]
                              @answer[:purchase_id] = @pur_add[:id]
                              @answer[:que_id] = q[:id]
                              
                             if q[:que_type]=='text' || q[:que_type]=='para' || q[:que_type]=='select' 
                                  @answer[:answer] = params[:que][q[:id].to_s][0]
                             else
                                  @answer[:answer] = params[:que][q[:id].to_s].join(',')
                             end 
                             @answer.save
                         end 
                      end    
                    end
                  end 
                    
                    
                if @waivers.count > 0 
                   
                    for q in @waivers
                      if params[:que]
                        if params[:que][q[:id].to_s]
                          @answer = Answer.new
                          @answer[:event_id] = @pur_add[:event_id]
                          @answer[:user_id] = @pur_add[:user_id]
                          @answer[:purchase_id] = @pur_add[:id]
                          @answer[:que_id] = q[:id]
                          @answer[:answer] = params[:que][q[:id].to_s][0]
                          @answer.save
                        end
                     end   
                    end 
                end
                 
            end
            #############  tickets save start
            
            if params[:ctype]=='2'
                if params[:ticket_id]
                    if params[:ticket_id].count > 0
                        @ticket = params[:ticket_id]
                        k=0
                        
                        @ticket.each do |ticket|
                          
                              @tic = Purchase.new(params[:purchase_addresse])
                             
                              if params[:first_name][k+1]
                                  @tic[:first_name] = params[:first_name][k+1]
                              end
                              
                              if params[:last_name][k+1]
                                  @tic[:last_name] = params[:last_name][k+1]
                              end
                              
                              if params[:email][k+1]
                                  @tic[:email] = params[:email][k+1]
                              end
                              
                              if params[:prefix]
                                  @tic[:prefix] = params[:prefix][k]
                              end
                              
                              if params[:suffix]      
                                  @tic[:suffix] = params[:suffix][k]
                              end
                               
                              if params[:home_phone]      
                                  @tic[:home_phone] = params[:home_phone][k]
                              end
                              
                              if params[:cell_phone]      
                                  @tic[:cell_phone] = params[:cell_phone][k]
                              end
                              
                              ### bill address
                              if params[:bill_add1]     
                                  @tic[:bill_add1] = params[:bill_add1][k]
                              end
                              
                              if params[:bill_add2]     
                                  @tic[:bill_add2] = params[:bill_add2][k]
                              end
                              
                              if params[:bill_city]     
                                  @tic[:bill_city] = params[:bill_city][k]
                              end
                              
                              if params[:bill_state]     
                                  @tic[:bill_state] = params[:bill_state][k]
                              end
                              
                              if params[:bill_zip]     
                                  @tic[:bill_zip] = params[:bill_zip][k]
                              end
                              
                              if params[:bill_country]     
                                  @tic[:bill_country] = params[:bill_country][k]
                              end
                              
                              #####  home address
                              if params[:home_add1]     
                                  @tic[:home_add1] = params[:home_add1][k]
                              end
                              
                              if params[:home_add2]     
                                  @tic[:home_add2] = params[:home_add2][k]
                              end
                              
                              if params[:home_city]     
                                  @tic[:home_city] = params[:home_city][k]
                              end
                              
                              if params[:home_state]     
                                  @tic[:home_state] = params[:home_state][k]
                              end
                              
                              if params[:home_zip]     
                                  @tic[:home_zip] = params[:home_zip][k]
                              end
                              
                              if params[:home_country]     
                                  @tic[:home_country] = params[:home_country][k]
                              end
                              
                              ######  ship country
                              
                               if params[:ship_add1]     
                                  @tic[:ship_add1] = params[:ship_add1][k]
                              end
                              
                              if params[:ship_add2]     
                                  @tic[:ship_add2] = params[:ship_add2][k]
                              end
                              
                              if params[:ship_city]     
                                  @tic[:ship_city] = params[:ship_city][k]
                              end
                              
                              if params[:ship_state]     
                                  @tic[:ship_state] = params[:ship_state][k]
                              end
                              
                              if params[:ship_zip]     
                                  @tic[:ship_zip] = params[:ship_zip][k]
                              end
                              
                              if params[:ship_country]     
                                  @tic[:ship_country] = params[:ship_country][k]
                              end
                              
                              #####  work address
                              
                               if params[:work_add1]     
                                  @tic[:work_add1] = params[:work_add1][k]
                              end
                              
                              if params[:work_add2]     
                                  @tic[:work_add2] = params[:work_add2][k]
                              end
                              
                              if params[:work_city]     
                                  @tic[:work_city] = params[:work_city][k]
                              end
                              
                              if params[:work_state]     
                                  @tic[:work_state] = params[:work_state][k]
                              end
                              
                              if params[:work_zip]     
                                  @tic[:work_zip] = params[:work_zip][k]
                              end
                              
                              if params[:work_country]     
                                  @tic[:work_country] = params[:work_country][k]
                              end
                              
                              
                              
                              if params[:work_job_title] 
                                  @tic[:work_job_title] = params[:work_job_title][k]
                              end
                              
                              if params[:work_company] 
                                  @tic[:work_company] = params[:work_company][k]
                              end
                              
                              
                              if params[:work_phone] 
                                  @tic[:work_phone] = params[:work_phone][k]
                              end
                              
                              if params[:work_website] 
                                  @tic[:work_website] = params[:work_website][k]
                              end
                              
                              if params[:work_blog] 
                                  @tic[:work_blog] = params[:work_blog][k]
                              end
                              
                              if params[:gender] 
                                  @tic[:gender] = params[:gender][k]
                              end
                              
                              if params[:birth_date] 
                                  @tic[:birth_date] = params[:birth_date][k]
                              end
                              
                              if params[:age] 
                                  @tic[:age] = params[:age][k]
                              end
                               @barcode = SecureRandom.hex(10)
                               
                               @tic[:barcode_random] = @barcode
                               @tic[:total] = params[:ticket_qty_total][params[:ticket_id][k].to_s]
                               @tic[:ticket_id] = params[:ticket_id][k]
                               @tic[:transaction_key] = @pur_add[:id].to_s
                               @tic[:ticket_qty] = params[:ticket_qty][k]
                               @tic.save
                              
                                
                                
                                if  @questions.count > 0
                                    
                                    for q in @questions
                                      if params[:que]
                                          if params[:que][@tic[:ticket_id].to_s] 
                                              @answer = Answer.new
                                              @answer[:event_id] = @pur_add[:event_id]
                                              @answer[:user_id] = @pur_add[:user_id]
                                              @answer[:purchase_id] = @tic[:id]
                                              @answer[:que_id] = q[:id]
                                              
                                             if q[:que_type]=='text' || q[:que_type]=='para' || q[:que_type]=='select' 
                                                  @answer[:answer] = params[:que][@tic[:ticket_id].to_s] 
                                             else
                                                  @answer[:answer] = params[:que][@tic[:ticket_id].to_s] .join(',')
                                             end 
                                             @answer.save
                                         end 
                                      end    
                                    end
                                  end 
                                    
                                    
                                if @waivers.count > 0 
                                   
                                    for q in @waivers
                                       if params[:que]
                                          if params[:que][@tic[:ticket_id].to_s] 
                                            @answer = Answer.new
                                            @answer[:event_id] = @pur_add[:event_id]
                                            @answer[:user_id] = @pur_add[:user_id]
                                            @answer[:purchase_id] = @pur_add[:id]
                                            @answer[:que_id] = q[:id]
                                            @answer[:answer] = params[:que][@tic[:ticket_id].to_s][0]
                                            @answer.save
                                          end
                                       end   
                                    end 
                                end  
                                
                              k+=1
                        end #### ticket each end
                        
                    end #### ticket count end
                end ####  ticket exists end
            end ### ctype end 
            
            
            ############ tickets save end
            
            
            ##### ctype conditions for saperate tickets starts
            
             if params[:ctype]=='1' || params[:ctype]=='0' 
                 if params[:ticket_ids].count==1
                    @pur_add[:transaction_key] = @pur_add[:id]
                    @pur_add[:ticket_id] = params[:ticket_ids][0].to_i
                    @pur_add.save
                    
                 else
                    k=0
                    @tic_per = @pur_add[:all_ids].split(',')
                    @qty_per = @pur_add[:all_qtys].split(',')
                    @amt_per = @pur_add[:all_totals].split(',') 
                    @fees_per = params[:ticket_fees]
                    @ticamt_per = params[:ticket_amt]
      
                    for nt in @tic_per
                      @new_p = @pur_add.dup
                      @barcode = SecureRandom.hex(10)
                               
                      @new_p[:barcode_random] = @barcode
                      
                      @new_p[:ticket_id] = @tic_per[k].to_i
                      @new_p[:ticket_qty] = @qty_per[k].to_i
                      @new_p[:total] = @amt_per[k].to_f
                      @new_p[:total_fees] = @fees_per[k].to_f
                      @new_p[:ticket_amt] = @ticamt_per[k].to_f
                      
                     
                      @new_p[:transaction_key] = @pur_add[:id]
                      @new_p.save
                      
                      @answers = Answer.find(:all, :conditions => ['purchase_id = ?', @pur_add[:id]])
                      if @answers.count > 0
                          for ans in @answers
                              @new_ans = ans.dup
                              @new_ans[:purchase_id] = @new_p[:id]
                              @new_ans.save
                          end
                      end
                      k+=1
                    end
                 end   
           end 
             ##### ctype conditions for saperate tickets ends
            
            
           if session[:aff_user_join_id]!='' && session[:aff_user_join_id]!=nil && session[:aff_visiter_id]==session[:user_id] && session[:aff_event_id]==@pur_add[:event_id]
              @aff = Affiliate.find(session[:aff_affiliate_id])
              if @aff[:fee_amt]!='' && @aff[:fee_amt]!=nil
                @your_share = @aff[:fee_amt]
              else
                  @your_share = @aff[:fee_perc] * @pur_add[:total] /100
              end
              
              UserJoin.update_all(["ticket_sold = ticket_sold+? , sales = sales+?, share = share+? ", @pur_add[:ticket_qty], @pur_add[:total], @your_share], ["id = ?",session[:aff_user_join_id]])
              if @your_share > 0 
               @wallet_aff = Wallet.new
               @wallet_aff[:credit] = @your_share
               @wallet_aff[:user_id] = session[:aff_visiter_id]
               @wallet_aff[:aff_id] = session[:aff_user_join_id]
               @wallet_aff.save
             end  
              session[:aff_user_join_id] = ''
              session[:aff_visiter_id] = ''
              session[:aff_event_id] = ''
              session[:aff_affiliate_id] = ''
           end
           
           @site = SiteSetting.find(:first)
           if @site[:test_payments]==1
                   Purchase.update_all(["payment = 1 "], ["transaction_key = ?", @pur_add[:id]])
                   
                   flash[:notice1] = I18n.t 'event.purchase.pur_suc'
                   format.html { redirect_to(:action=>'order_confirmed/'+@pur_add[:id].to_s) }
           else  
              if @pur_add[:total]>0
                   if @site[:payment_gateway]=='auth'
                       format.html {  redirect_to(:action=>'order/'+@pur_add[:id].to_s)}
                   else
                       format.html {  redirect_to(:action=>'paypal/'+@pur_add[:id].to_s)}
                       
                       #format.html { render :text => params[:ticket_ids][0] }
                   end     
              else  
                   flash[:notice1] = I18n.t 'event.purchase.pur_suc'
                   @pur_add[:payment]=1
                   @pur_add.save
                   Purchase.update_all(['payment=1'], ['transaction_key=?',@pur_add[:id]])
                   format.html { redirect_to(:action=>'order_confirmed/'+@pur_add[:id].to_s) }
              end
           end  
        end
    
    end
  end
  
  
 
 def place_order_attendee
   
    if request.post?
      
        respond_to do |format|
            @pur_add = Purchase.new(params[:purchase_addresse])
            @pur_add[:first_name] = params[:first_name][0]
            @pur_add[:last_name] = params[:last_name][0]
            @pur_add[:email] = params[:email][0]
            
            @eve = Event.find(@pur_add[:event_id])
            @questions = Question.find(:all, :conditions => ['event_id=? AND que_type!="waiver" AND (rules="11" or rules="1")', @eve[:id]])
            @waivers = Question.find(:all, :conditions => ['event_id=? AND que_type="waiver" AND (rules="11" or rules="1")', @eve[:id]]) 
             
            if params[:ticket_ids]
              @pur_add[:all_ids] = params[:ticket_ids].join(',')
            end
            
            if params[:ticket_qtys]
              @pur_add[:all_qtys] = params[:ticket_qtys].join(',')
            end
            
            if params[:ticket_totals]
              @pur_add[:all_totals] = params[:ticket_totals].join(',')
            end
           
           #####  home address
           
            if params[:home_city]     
                @pur_add[:home_city] = params[:home_city][0]
            end
            
            if params[:home_state]     
                @pur_add[:home_state] = params[:home_state][0]
            end
           
            #####  work address
            
            if params[:work_city]     
                @pur_add[:work_city] = params[:work_city][0]
            end
            
            if params[:work_state]     
                @pur_add[:work_state] = params[:work_state][0]
            end
            
            if params[:work_job_title] 
                @pur_add[:work_job_title] = params[:work_job_title][0]
            end
            
            if params[:work_company] 
                @pur_add[:work_company] = params[:work_company][0]
            end
            
            if params[:work_website] 
                @pur_add[:work_website] = params[:work_website][0]
            end
            
            if params[:work_blog] 
                @pur_add[:work_blog] = params[:work_blog][0]
            end
           
            if params[:ticket_id] 
                @pur_add[:ticket_id] = params[:ticket_id][0]
            end
            @pur_add.save
           
          
                 if  @questions.count > 0
                    
                    for q in @questions
                       if params[:que]
                          if params[:que][q[:id].to_s] 
                              @answer = Answer.new
                              @answer[:event_id] = @pur_add[:event_id]
                              @answer[:user_id] = @pur_add[:user_id]
                              @answer[:purchase_id] = @pur_add[:id]
                              @answer[:que_id] = q[:id]
                              
                             if q[:que_type]=='text' || q[:que_type]=='para' || q[:que_type]=='select' 
                                  @answer[:answer] = params[:que][q[:id].to_s][0]
                             else
                                  @answer[:answer] = params[:que][q[:id].to_s].join(',')
                             end 
                             @answer.save
                         end 
                      end   
                    end
                  end 
                    
                    
                if @waivers.count > 0 
                    for q in @waivers
                      if params[:que]
                        if params[:que][q[:id].to_s]
                          @answer = Answer.new
                          @answer[:event_id] = @pur_add[:event_id]
                          @answer[:user_id] = @pur_add[:user_id]
                          @answer[:purchase_id] = @pur_add[:id]
                          @answer[:que_id] = q[:id]
                          @answer[:answer] = params[:que][q[:id].to_s][0]
                          @answer.save
                        end
                      end  
                    end 
                end
           
           @event_attendee = EventAttendee.new(params[:attendee])
           @event_attendee.save
           
           @pur_add[:attendee_id] = @event_attendee[:id]
           @pur_add.save
           
           if params[:ticket_ids].count == 1
                
                @pur_add[:transaction_key] = @pur_add[:id]
                @pur_add[:ticket_id] = params[:ticket_ids][0].to_i
                @pur_add.save
                generate_pdf(@pur_add, @eve)
                
             else
                k=0
                    @tic_per = @pur_add[:all_ids].split(',')
                    @qty_per = @pur_add[:all_qtys].split(',')
                    @amt_per = @pur_add[:all_totals].split(',') 
                    @fees_per = params[:ticket_fees]
                    @ticamt_per = params[:ticket_amt]
      
                    for nt in @tic_per
                      @new_p = @pur_add.dup
                      @barcode = SecureRandom.hex(10)
                               
                      @new_p[:barcode_random] = @barcode
                      
                      @new_p[:ticket_id] = @tic_per[k].to_i
                      @new_p[:ticket_qty] = @qty_per[k].to_i
                      @new_p[:total] = @amt_per[k].to_f
                      @new_p[:total_fees] = @fees_per[k].to_f
                      @new_p[:ticket_amt] = @ticamt_per[k].to_f
                      
                      @new_p[:transaction_key] = @pur_add[:id]
                      @new_p.save
                      generate_pdf(@new_p, @eve)
                      
                      @answers = Answer.find(:all, :conditions => ['purchase_id = ?', @pur_add[:id]])
                      if @answers.count > 0
                          for ans in @answers
                              @new_ans = ans.dup
                              @new_ans[:purchase_id] = @new_p[:id]
                              @new_ans.save
                          end
                      end
                      k+=1
                  end
             end              
            UserMailer.confirm_order(@pur_add).deliver
                   
            @ids = @pur_add[:all_ids].split(',')
            @qtys = @pur_add[:all_qtys].split(',')
            
            k=0
            for id in @ids
                @tot_tic = Ticket.find(id.to_i)
                used = @qtys[k].to_i + @tot_tic[:used]
                Ticket.update_all(["used = ? ", used], ["id = ?", id.to_i])
                k+=1
            end
             
          flash[:notice1] = I18n.t 'event.purchase.attendees_successfully_added'
          format.html { redirect_to(:controller => 'manage_event', :action=>'orders/'+@pur_add[:event_id].to_s) }
       end
    end
 end
 
 
 
 
 ######  Order Confirm ####
 
 def order_confirmed
   
   
     
    @pur = Purchase.find(params[:id])
    @event = Event.find(@pur[:event_id])
    @order = OrderForm.find(:first, :conditions => ['event_id=?', @event[:id]])
    @site = SiteSetting.find(:first)
    
    @meta_title = @event[:event_title]#I18n.t 'meta_title.ticket_purchase'
    @meta_keyword = @event[:event_title].gsub(" ", ",")
    @meta_desc = @event[:event_title]+ ' -- '+@event[:event_start_date_time].strftime('%A, %B %d, %Y').to_s+' -- '+@event[:organizer_host]
     
     
    lang = Language.find_name(@event[:language_id])
    set_locale(lang)
            
    if @order
    else
      @order = OrderForm.new
    end
    
    if @pur[:all_ids]!=nil && @pur[:all_qtys]!=nil
        @ids = @pur[:all_ids].split(',')
        @qtys = @pur[:all_qtys].split(',')
        
        k=0
        for id in @ids
            @tot_tic = Ticket.find(id.to_i)
            used = @qtys[k].to_i + @tot_tic[:used]
            Ticket.update_all(["used = ? ", used], ["id = ?", id.to_i])
            k+=1
        end
    end
    
    if @pur[:promotioal_code_id] > 0
       PromotionalCode.update_all(["used_cnt = used_cnt+1 "], ["id = ?", @pur[:promotioal_code_id]])  
    end
    
    @all_pur = Purchase.find(:all, :conditions => ['transaction_key=?', @pur[:id]])  
    if @all_pur.count > 1
      for all in @all_pur
        generate_pdf(all, @event)
       
      end
    end
    generate_pdf(@pur, @event)
    UserMailer.confirm_order(@pur).deliver
    UserMailer.confirm_order_admin(@pur).deliver
    
    @site = SiteSetting.find(:first)
    @user = User.find(session[:user_id])
    @org_id = @event[:organizer_id]
    @event_theme = EventTheme.one_theme(@event[:id])
    if @event_theme
    else @event_theme = Theme.find_first_theme
    end
    @one_theme = @event_theme
     
   render :layout => 'application_login'  
 end 
  
  
  
  
  def order
     @site = SiteSetting.find(:first)
     @pur = Purchase.find(params[:id])
     @event = Event.find(@pur[:event_id])
      @user = User.find(session[:user_id])
  end 
  
  def auth_net_aim
    @auth = AuthorizeSetting.find(:first)
      @x_card_num=params['x_card_num']
      @x_exp_date=params['x_exp_date']
      @x_card_code=params['x_card_code']
      
      @x_first_name=params['x_first_name']
      @x_last_name=params['x_last_name']
      @x_address=params['x_address']
      
      @x_city=params['x_city']
      @x_state=params['x_state']
      @x_zip=params['x_zip']
      @x_country=params['x_country']
      
      @x_login=@auth['x_login']
      @x_tran_key=@auth['x_trans_key']
      @x_type=@auth['x_type']
      @x_method=@auth['x_method']
      @x_description=@auth['x_desc']
      
      @site_status=@auth['x_site_status']  
      
      @post_url = "https://test.authorize.net/gateway/transact.dll"
      
      if(@site_status=='sandbox')
          
        @post_url = "https://test.authorize.net/gateway/transact.dll"
        @test_request=true
      
      else
      
        @post_url = "https://secure.authorize.net/gateway/transact.dll"
        @test_request=true
      end
      
       @total = params['total']
        
        
        # the API Login ID and Transaction Key must be replaced with valid values
        @post_values = [
          
          ["x_login", @x_login],
          ["x_tran_key",@x_tran_key],
        
          ["x_version","3.1"],
          ["x_delim_data","TRUE"],
          ["x_delim_char","|"],
          ["x_relay_response","FALSE"],
        
          ["x_type", @x_type],
          ["x_method", @x_method],
          ["x_card_num", @x_card_num],
          ["x_exp_date", @x_exp_date],
        
          ["x_amount", @total],
          ["x_description", @x_description],
        
          ["x_first_name", @x_first_name],
          ["x_last_name", @x_last_name],
          ["x_address" , @x_address],
          ["x_state" , @x_state],
          ["x_zip" , @x_zip],
          ["x_modname" , @modname],
          ["x_test_request", @test_request]
          
        ]
        
        @request = Curl::Easy.http_post(@post_url, {:x_login => @x_login, :x_tran_key => @x_tran_key , :x_version => "3.1", :x_delim_data => "TRUE", :x_delim_char => "|", :x_relay_response => "FALSE", :x_type => @x_type, :x_method => @x_method, :x_card_num => @x_card_num, :x_exp_date => @x_exp_date, :x_amount => @total, :x_description => @x_description, :x_first_name => @x_first_name, :x_last_name => @x_last_name , :x_address => @x_address, :x_state => @x_state, :x_zip => @x_zip, :x_modname => @x_modname, :x_test_request => @x_test_request})
        render :text => @request.body_str  
  end
  
  
  
  def paypal
     @site = SiteSetting.find(:first)
     @pur = Purchase.find(params[:id])
     @event = Event.find(@pur[:event_id])
     @paypal = PaypalSetting.find(:first)
     @user = User.find(session[:user_id])
     
     @Paypal_Email = @paypal[:paypal_email]   
     @Paypal_Status = @paypal[:site_status]

      lang = Language.find_name(@event[:language_id])
            set_locale(lang)
     @Paypal_Url='https://www.sandbox.paypal.com/cgi-bin/webscri'

      if @Paypal_Status=='Sandbox'
          @Paypal_Url='https://www.sandbox.paypal.com/cgi-bin/webscri'
      end
      
      if @Paypal_Status=='Live'
          @Paypal_Url='https://www.paypal.com/cgi-bin/webscri'
      end

      @amt = @pur[:total]
      #@paypal_add_fees = @paypal[:transaction_fees]
      #@add_fees = @paypal_add_fees * @amt/100
      @tot = @amt #+@add_fees
      @add_fees = 0
      @total = @amt #+@add_fees #paypal_amt(@tot)
      @currency_code = @site[:currency_code]
      @business = @Paypal_Email

      @return = APP_CONFIG['development']['site_url']+'tickets/paypal_return/'+@pur[:id].to_s+'?user_id='+@user[:id].to_s
      @cancel_return = APP_CONFIG['development']['site_url']+'tickets/paypal_cancel/'+@pur[:id].to_s+'?user_id='+@user[:id].to_s
      @notify_url = APP_CONFIG['development']['site_url']+'tickets/paypal_ipn/'
      @custom = @total.to_s+'#'+@user[:id].to_s+'#'+@pur[:id].to_s

      @item_name = (I18n.t 'event.purchase.new_pur')+ @pur[:first_name] +' '+ @pur[:last_name]+(I18n.t 'event.purchase.of_event')+@event[:event_title]
      @item_number = @pur[:random_no]
      
      @amount = @total

    #render :text => params
  end 
  
  
  
  private 
  
  
  def cancel_purchase(id)
    
      @pur = Purchase.find(id)
      
      @tic = @pur[:all_ids].split(',')
      @qty = @pur[:all_qtys].split(',')
      @amt = @pur[:all_totals].split(',')  
      user_id = @pur[:user_id]
      k=0
      
      for t in @tic
          @ticket = Ticket.find(t.to_i)
          qty = @ticket[:used]-@qty[k].to_i
         # Ticket.update_all([" used = ? ", qty ], ["id = ?", @ticket[:id]])
          k+=1
      end
      
      Purchase.destroy_all("transaction_key = "+@pur[:id].to_s)
      Wallet.destroy_all("purchase_id = "+@pur[:id].to_s)
      @pur.destroy  
      
  end
end