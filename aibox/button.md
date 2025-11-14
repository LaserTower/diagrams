При нажатии на кнопку обьект CallbackQueryJob попадает в очередь 'callback-query'

При выполнении задания вызывается событие 'callback_query.' плюс callback_data это позволяет динамически управлять кнопками

Для выполнения кнопки необходимо 
зарегистрировать обработчик события нажатия в файле app/Features/Profile/ProfileCallbackQuerySubscriber.php

        $events->listen(
            'callback_query.profile:set_gender:*',
            [GenderForm::class, 'setGender']
        );
и указать в кнопке какое событие будет вызвано - здесь это profile:set_gender 
через двоеточие указана фича, функция, параметры
